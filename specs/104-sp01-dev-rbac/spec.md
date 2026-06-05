# Feature 104 — sp01/dev RBAC (instance of the 007-rbac engine)

**Feature Branch**: `104-sp01-dev-rbac`

**Created**: 2026-06-04

**Status**: Implemented on master (engine: [007-rbac](../007-rbac/spec.md)).

**Input**: Instance feature — pins the single sp01/dev deployment of the
generic Foundry managed-identity RBAC engine. Deploys **no new module code**;
it selects + parameterizes the engine via one tfvars file and a backend state
key, reading the 103-sp01-dev-services deployment's remote state to discover
the account/project managed identities and their target resource scopes.

## What this instance is

| Dimension | Value |
|---|---|
| Engine | [007-rbac](../007-rbac/spec.md) — `terraform/rbac/` + `modules/rbac/` |
| Tenant / environment | `sp01` / `dev` |
| Topology | `spoke` |
| Region | `swc` (swedencentral) |
| tfvars | [variables/sp01/dev/rbac.tfvars.json](../../variables/sp01/dev/rbac.tfvars.json) |
| Backend state key | `sp01/dev/rbac.tfstate` |
| Upstream state | `sp01/dev/services.tfstate` (103-sp01-dev-services) |
| CI gate | [.github/workflows/rbac.yml](../../.github/workflows/rbac.yml) (watches the tfvars path) |
| Rollout | `gh workflow run deploy.yaml -f service=rbac -f tenant=sp01 -f environment=dev -f action=apply -f apply=true` |

## Pinned configuration (source of truth: the tfvars file)

- `subscription_id`: injected at runtime by `deploy.yaml`
  (`-var subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}`); the
  placeholder in the tfvars is intentional.
- `services_state_backend`: points at `sp01/dev/services.tfstate` in the hub
  state account (`rg-tfs-shd-hub-npd-swc-001` /
  `sttfsshdhubnpdswc001` / `tfstate`).
- `enable_aifoundry_user_owned_storage`: `true` — must mirror the 103
  services instance (FR-104-03).
- `enable_aifoundry_keyvault_connection`: `true` — must mirror the 103
  services instance (FR-104-03).
- `agent_storage_purpose`: `agt` — must equal the 103 services instance's
  agent storage purpose (FR-104-03).
- `account_storage_purpose`: `act` — must equal the 103 services instance's
  account storage purpose (FR-104-03).

## Grants applied (computed by the engine from the matched scopes)

Account managed identity:

- Key Vault Crypto Service Encryption User + Crypto User (on the connected
  vault).
- Contributor (on the services resource group).
- Storage Blob Data Contributor (on the **account** user-owned storage).

Project managed identity:

- Storage Blob Data Owner + File Data Privileged Contributor (on the
  **agent** storage).
- Search Index Data Contributor + Search Service Contributor (on the search
  service).
- Cosmos DB Operator + DocumentDB Account Contributor (control-plane, on the
  cosmos account) **plus** the Cosmos SQL built-in Data Contributor data-plane
  role assignment (via the engine's `azapi` SQL role path).

## Dependencies / ordering

- Depends on [103-sp01-dev-services](../103-sp01-dev-services/spec.md): the
  services deployment MUST exist (its tfstate populated) before this RBAC
  stack runs, because the engine reads the account/project principal IDs and
  the target resource IDs from that remote state. Rollout order:
  **services apply → rbac apply**.
- The engine gates every `count`/`for_each` key on known-at-plan presence
  booleans derived from the remote state, so a partially-populated upstream
  state degrades to fewer grants rather than failing the plan.

## Requirements

- **FR-104-01**: Consume the 007-rbac engine unchanged — no engine
  module/stack code is modified by this feature.
- **FR-104-02**: All sp01/dev-specific configuration (state backend, toggles,
  storage purposes) lives ONLY in the tfvars file.
- **FR-104-03**: The four engine inputs that select storages and KV behaviour
  (`enable_aifoundry_user_owned_storage`, `enable_aifoundry_keyvault_connection`,
  `agent_storage_purpose`, `account_storage_purpose`) MUST match the
  corresponding values in the 103-sp01-dev-services tfvars, so the RBAC
  engine resolves the same storages the services engine provisioned.
- **FR-104-04**: Live rollout MUST go through the GitHub `deploy` workflow
  (`service=rbac tenant=sp01 environment=dev`); never `terraform apply`
  locally.

## Acceptance

1. `terraform validate` on `terraform/rbac` with this tfvars succeeds.
2. Engine `terraform test` (5 stack + 2 module cases) remains green
   (unchanged by this instance).
3. tfvars passes the engine `check.tf` prerequisites: both storage purposes
   set + distinct, KV-connection toggle paired with a KV present upstream.
4. `deploy.yaml` dispatch with `service=rbac tenant=sp01 environment=dev`
   plans + applies cleanly against `sp01/dev/rbac.tfstate` AFTER the 103
   services deployment exists.

## Out of scope

- Any engine behaviour change (new role, new resource type, new principal) —
  those belong in the 007-rbac engine spec, not this instance.
- The services deployment itself (owned by 103-sp01-dev-services).

## AMENDMENT 2026-06-05 — opt sp01/dev into the project-MI AcrPull grant (FR-104-05)

> **Why.** A private project's Hosted-Agent `create_agent` returns **503**
> because the project system-assigned MI lacks **AcrPull** on the registry (the
> runtime cannot authenticate to pull the image). The 007-rbac engine gained the
> grant in **FR-064** (toggle `enable_project_acr_pull`, default off); this
> amendment is the sp01/dev **instance opt-in**. Paired with the project
> ContainerRegistry connection (103 FR-103-12 / engine FR-063): both are required
> and the rollout order is `services` then `rbac`.

- **FR-104-05**: The sp01/dev `rbac` tfvars MUST set
  `enable_project_acr_pull: true` so the 007-rbac engine (FR-064) emits the
  `project-acr-pull` grant (AcrPull `7f951dda-…` on the registry to the project
  MI). Gated by the engine on a project + container_registry present in the
  consumed services state — both already provisioned by 103. Pure instance
  parameterization; the engine is unchanged.

### Acceptance (FR-104-05)

5. `variables/sp01/dev/rbac.tfvars.json` sets `enable_project_acr_pull: true`.
6. `terraform validate -backend=false` on `terraform/rbac` with this tfvars
   succeeds; engine `terraform test` stays green (no engine change).
7. Live (after rollout, AFTER 103 FR-103-12's `services` apply): the project MI
   `502bbe0f-257c-4d33-9327-f8dc96ae71a2` holds **AcrPull** on ACR
   `cruc1uc1sp01devswc001`.

### Out of scope for FR-104-05

- Any 007-rbac engine change (the grant capability is the already-merged FR-064
  engine toggle).
- The project ContainerRegistry connection (103-sp01-dev-services FR-103-12 /
  engine FR-063).
