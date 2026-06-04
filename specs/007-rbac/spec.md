# 007-rbac — Foundry RBAC engine (account + project managed-identity role grants)

> **Engine feature (00n band).** Generic, reusable RBAC stack that deploys
> NOTHING by itself. It grants the Azure AI Foundry **account** and **project**
> system-assigned managed identities the exact role assignments the Microsoft
> portal Standard-Agent ARM template emits over the Foundry's bring-your-own
> (BYO) backings — Key Vault, user-owned Storage, agent Storage, AI Search and
> Cosmos DB. Every concrete grant set is parameterised 100% via a tenant/env
> `variables/<tenant>/<env>/rbac.tfvars.json` + the consumed services-stack
> remote state. Instance features (`10n`) only select/parameterise this engine.

## Summary

When the Foundry account + project are created with **system-assigned**
identities and wired to BYO data services (the `006-services` engine), those
identities have **no data-plane access** to the backings until the matching
Azure RBAC role assignments exist. The portal Standard-Agent template creates a
fixed matrix of role assignments to close that gap. This engine reproduces that
matrix as a dedicated Terraform stack so the deployment is functionally
identical to the portal-provisioned environment, while keeping the assignments
in their own state (separation of duties: identity/data-plane grants are
managed apart from the resources themselves).

This engine consumes the `006-services` stack **remote state** (`naming`,
`resource_ids`, `resource_group_id`) to discover the Foundry account, the
Foundry project, and each BYO target by `service_type`/`service_purpose`, then
reads the account/project **principalId**s via `azapi` data sources and fans the
role assignments out through a generic `modules/rbac` module.

## Goals

- Reproduce, exactly, the portal Standard-Agent template's role-assignment
  matrix for the Foundry **account** and **project** managed identities.
- Stay an engine: no hard-coded tenant/env/resource values; everything resolved
  from the consumed services remote state + the stack's own tfvars toggles.
- Be idempotent and re-runnable; assignments keyed deterministically.
- Default to doing nothing unsafe: a grant group is emitted **only** when both
  the relevant Foundry principal and the target service are present in the
  consumed state and the matching toggle is on.

## Non-goals

- Creating any data services, Foundry account/project, or networking — those
  belong to `006-services` / `004-vnet`. This stack only assigns roles.
- Group/user/service-principal RBAC (human access). Out of scope; this engine
  is exclusively the Foundry **account + project** managed-identity grants.
- CMK (customer-managed key) encryption identity grants — the portal template's
  CMK-gated Key Vault Crypto User assignment on a separate CMK vault is **out of
  scope** (the `006` deployment uses platform-managed encryption, not CMK).

## Inputs (engine surface)

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `subscription_id` | string | — | Target subscription (provider + role-definition id scope). |
| `services_state_backend` | object({resource_group_name, storage_account_name, container_name, key}) | — | azurerm backend of the consumed `006-services` state. |
| `enable_aifoundry_user_owned_storage` | bool | `false` | Mirror of the services toggle; gates the **account** MI Storage Blob Data Contributor grant on the user-owned storage. |
| `enable_aifoundry_keyvault_connection` | bool | `false` | Mirror of the services toggle; gates the **account** MI Key Vault Crypto grants on the Key Vault. |
| `agent_storage_purpose` | string\|null | `null` | `service_purpose` (3×`[a-z0-9]`) of the **agent** storage (project MI grants). |
| `account_storage_purpose` | string\|null | `null` | `service_purpose` of the **account/user-owned** storage (account MI grant). Must differ from `agent_storage_purpose`. |

## Role-assignment matrix (FR-046 … FR-058)

Role-definition GUIDs are taken verbatim from the portal template. Each
assignment's `role_definition_id` is built as
`/subscriptions/<sub>/providers/Microsoft.Authorization/roleDefinitions/<guid>`;
`principal_type = "ServicePrincipal"` for all ARM assignments.

### Account managed identity (Foundry `Microsoft.CognitiveServices/accounts`)

- **FR-046** — Key Vault **Crypto Service Encryption User**
  (`b86a8fe4-44ce-4948-aee5-eccb2c155cd7`) on the Key Vault.
  *Gated on:* keyvault present ∧ `enable_aifoundry_keyvault_connection`.
- **FR-047** — Key Vault **Crypto User**
  (`f25e0fa2-a7c8-4377-a976-54943a77a395`) on the Key Vault.
  *Gated on:* keyvault present ∧ `enable_aifoundry_keyvault_connection`.
- **FR-048** — **Contributor** (`b24988ac-6180-42a0-ab88-20f7382dd24c`) on the
  services resource group (`resource_group_id` from remote state).
  *Gated on:* aifoundry account present.
- **FR-049** — Storage **Blob Data Contributor**
  (`ba92f5b4-2d11-453d-a403-e96b0029c9fe`) on the **user-owned** storage.
  *Gated on:* user-owned storage present ∧
  `enable_aifoundry_user_owned_storage`.

### Project managed identity (Foundry `…/accounts/projects`)

- **FR-050** — Storage **Blob Data Contributor**
  (`ba92f5b4-2d11-453d-a403-e96b0029c9fe`) on the **agent** storage.
- **FR-051** — Storage **Blob Data Owner**
  (`b7e6dc6d-f1e8-4753-8033-0f276bb0955b`) on the **agent** storage.
- **FR-052** — Storage **File Data Privileged Contributor**
  (`974c5e8b-45b9-4653-ba55-5f855dd0fb88`) on the **agent** storage.
  *FR-050…052 gated on:* project present ∧ agent storage present.
- **FR-053** — **Search Index Data Contributor**
  (`8ebe5a00-799e-43f5-93ac-243d3dce84a7`) on the AI Search service.
- **FR-054** — **Search Service Contributor**
  (`7ca78c08-252a-4471-8644-bb5ff32d4ba0`) on the AI Search service.
  *FR-053…054 gated on:* project present ∧ search present.
- **FR-055** — **Cosmos DB Operator**
  (`230815da-be43-4aae-9cb4-875f7bd000aa`) on the Cosmos DB account.
- **FR-056** — **DocumentDB Account Contributor**
  (`5bd9cd88-fe45-4216-938b-f97437e15450`) on the Cosmos DB account.
- **FR-057** — Cosmos DB **Built-in Data Contributor** SQL role
  (`00000000-0000-0000-0000-000000000002`) via
  `Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments`, scoped to the
  Cosmos account (data-plane).
  *FR-055…057 gated on:* project present ∧ cosmosdb present.

### Cross-cutting

- **FR-058** — A grant group MUST NOT be emitted when its Foundry principal or
  its target service is absent from the consumed services remote state, or when
  its mirror toggle is off. Resolution is from the engine's `naming` /
  `resource_ids` outputs by `service_type` (and `service_purpose` for the two
  storages); never by hard-coded names.

## Clarifications

- **C-062** — *Principal id discovery.* The account/project **principalId**s are
  read at apply time via `azapi` data sources on the resource ids supplied by
  the services remote state (`response_export_values = ["identity.principalId"]`).
  `count`/`for_each` keys are derived only from remote-state values (known at
  plan); principal-id values may be computed without breaking the plan.
- **C-063** — *Two-storage disambiguation.* When the services stack selects two
  storages (agent + account/user-owned), this engine distinguishes them by
  `service_purpose` using the same `agent_storage_purpose` /
  `account_storage_purpose` inputs the services stack used. Both must be set and
  distinct whenever `enable_aifoundry_user_owned_storage` is on.
- **C-064** — *Role-assignment naming.* Assignments use Terraform/azurerm
  auto-generated names (state-tracked idempotency), not the portal's
  `guid(scope, role, name)` names. Functionally equivalent; the
  scope+role+principal triple is unique per assignment.
- **C-065** — *Separate state / separate stack.* RBAC lives in its own
  `terraform/rbac/` stack + `rbac/…tfvars.json` backend key, decoupled from
  `006-services`, so identity/data-plane grants can be planned, reviewed and
  rolled back independently (user-confirmed: "In a separate RBAC stack/module").
- **C-066** — *CMK grant excluded.* The portal template's CMK-gated Key Vault
  Crypto User assignment (`14b46e9e-c2b7-41b4-b07b-48a6ebf60603`) on a dedicated
  CMK vault is intentionally **not** reproduced — the `006` deployment uses
  platform-managed encryption, so there is no CMK vault to grant on.

## Validation criteria

- **VC-30** — With aifoundry+project+two-storage+search+cosmos+keyvault present
  and both toggles on + distinct purposes, the role-assignment matrix contains
  exactly: 2 account-KV grants, 1 account-RG Contributor, 1 account-userOwned
  storage grant, 3 project-agent-storage grants, 2 project-search grants, 2
  project-cosmos ARM grants, and 1 project-cosmos SQL data-plane grant.
- **VC-31** — Default (all toggles off / no targets): zero role assignments and
  zero cosmos SQL role assignments.
- **VC-32** — Each storage grant resolves to the correct storage by
  `service_purpose` (account grant → `account_storage_purpose`; project grants →
  `agent_storage_purpose`).
- **VC-33** — `enable_aifoundry_user_owned_storage = true` with fewer than two
  storages (or missing purposes) is rejected by a stack `check`.
- **VC-34** — `enable_aifoundry_keyvault_connection = true` with no keyvault in
  the consumed state is rejected by a stack `check`.
- **VC-35** — `terraform fmt -recursive` clean; `terraform validate` and
  `terraform test` green for both `modules/rbac` and `terraform/rbac`.

## Out of scope

Human/group RBAC, CMK identity grants, any resource creation, and any
deploy-time rollout (prepare-only).

## AMENDMENT 2026-06-04 — FR-046 label correction (Key Vault Secrets Officer)

> **Why.** FR-046 was authored as "Key Vault **Crypto Service Encryption
> User**" but the GUID copied from the portal Standard-Agent template,
> `b86a8fe4-44ce-4948-aee5-eccb2c155cd7`, is in fact **Key Vault Secrets
> Officer** (Crypto Service Encryption User is `e147488a-f6f5-4113-8e2d-b22465e65bf6`).
> The engine therefore already grants the account managed identity **Key Vault
> Secrets Officer** — exactly the data-plane secret-write role the Foundry
> account needs to store connection secrets (e.g. the App Insights tracing
> connection's ApiKey) in its BYO Key Vault. This amendment corrects the name
> and the in-code identifier so the matrix is self-documenting; it is a pure
> relabel with **no change to the granted GUID** and therefore no change to the
> effective permission.

- **FR-046 (corrected)** — Key Vault **Secrets Officer**
  (`b86a8fe4-44ce-4948-aee5-eccb2c155cd7`) on the Key Vault, granted to the
  **account** managed identity. *Gated on:* keyvault present ∧
  `enable_aifoundry_keyvault_connection`. The Terraform identifiers are renamed
  to match: `role_guids.kv_crypto_service_encryption_user` →
  `role_guids.kv_secrets_officer`, and the assignment key
  `account-kv-crypto-service-encryption-user` →
  `account-kv-secrets-officer`.

### Clarifications — Session 2026-06-04 (FR-046 correction)

- **C-067 — Pure relabel, identical GUID.** Only the role's human-readable name
  and the Terraform local/assignment identifiers change; the
  `role_definition_id` GUID is unchanged, so an already-applied assignment is
  functionally identical. RBAC has not yet been applied for any environment, so
  the assignment-key rename causes no state churn.
- **C-068 — This grant is what unblocks `006`'s secret-bearing connections.**
  The account-MI Secrets Officer grant is the data-plane permission the
  `006-services` App Insights connection (and any future ApiKey connection)
  requires to write its secret into the account's attached Key Vault. Because
  `rbac` runs after `services`, the FR-060 (`006`) `enable_aifoundry_agent_finalization`
  toggle defers those secret-bearing resources to a second `services` pass that
  runs **after** this grant exists. The two amendments are paired.

### Validation criteria (FR-046 correction)

- **VC-36** — The role-assignment matrix still emits exactly one account-MI Key
  Vault Secrets Officer grant with `role_definition_id` ending
  `/b86a8fe4-44ce-4948-aee5-eccb2c155cd7` when keyvault is present and the
  toggle is on; the assignment key is `account-kv-secrets-officer`.
- **VC-37** — No remaining reference to `kv_crypto_service_encryption_user`
  exists under `terraform/rbac/`; `terraform fmt`/`validate`/`test` stay green.

### Out of scope (FR-046 correction)

Adding the *actual* Key Vault Crypto Service Encryption User role
(`e147488a-…`) — the `006` deployment uses platform-managed encryption (no CMK),
so that crypto grant is not required (consistent with C-066).
