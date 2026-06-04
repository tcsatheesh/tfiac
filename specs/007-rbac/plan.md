# Plan — 007-rbac engine

## Technology / conventions

- Terraform `~> 1.9` (CI pins 1.13.4). Providers: `azurerm ~> 4.0`,
  `azapi ~> 2.4`. Tests use `mock_provider` + `override_data` (NEVER a live
  backend; `-backend=false`).
- Mirrors the existing engine-stack layout under `terraform/services/`:
  `versions.tf`, `providers.tf`, `backend.tf`, `variables.tf`, `locals.tf`,
  `main.tf`, `check.tf`, `outputs.tf`, `data.*.tf`, `tests/`, `README.md`.
- New reusable module `modules/rbac/` (modern typed style — NOT the loose
  `temp/_legacy/rbac`): a pure role-assignment fan-out engine.
- Consumes the `006-services` remote state for target ids; reads Foundry
  account/project principalIds via `azapi` data sources.
- Engine/instance split: this feature ships ONLY the engine (stack + module +
  CI). The instance tfvars + rollout are feature `104-sp01-dev-rbac`.

## Module `modules/rbac/`

- **A-046-01** `versions.tf` — terraform + azurerm + azapi pins.
- **A-046-02** `variables.tf` —
  - `role_assignments` = `map(object({ scope_id, role_definition_id,
    principal_id, principal_type }))` (ARM assignments fan-out).
  - `cosmos_sql_role_assignments` = `map(object({ cosmos_account_id,
    sql_role_definition_id, principal_id }))` (data-plane fan-out).
  - Input validation: maps may be empty; ids non-empty when present.
- **A-046-03** `main.tf` —
  - `azurerm_role_assignment` `for_each = var.role_assignments` →
    `scope`, `role_definition_id`, `principal_id`, `principal_type`.
  - `azapi_resource` `for_each = var.cosmos_sql_role_assignments`, type
    `Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15`,
    `parent_id = cosmos_account_id`, body `{ roleDefinitionId, principalId,
    scope }`, `name = uuidv5(...)` deterministic.
- **A-046-04** `outputs.tf` — `role_assignment_ids` (map key→id),
  `cosmos_sql_role_assignment_ids` (map key→id).
- **A-046-05** `tests/` — happy (non-empty maps create N assignments) + default
  (empty maps create zero). `mock_provider "azurerm"`, `mock_provider "azapi"`.

## Stack `terraform/rbac/`

- **A-046-06** `versions.tf` / `providers.tf` / `backend.tf` — copy services
  shapes (azurerm `storage_use_azuread`, azuread-auth backend).
- **A-046-07** `variables.tf` — `subscription_id`, `services_state_backend`
  (object), `enable_aifoundry_user_owned_storage`,
  `enable_aifoundry_keyvault_connection`, `agent_storage_purpose`,
  `account_storage_purpose` (with `^[a-z0-9]{3}$` validation + "differs from
  agent" validation mirroring the services stack).
- **A-046-08** `data.services.tf` — `data.terraform_remote_state.services`
  (always read).
- **A-046-09** `data.principals.tf` — `azapi_resource` data sources for the
  account + project principalId (count-gated on presence;
  `response_export_values = ["identity.principalId"]`).
- **A-046-10** `locals.tf` — resolve from remote state:
  - `naming` = `outputs.naming`, `resource_ids` = `outputs.resource_ids`,
    `services_rg_id` = `outputs.resource_group_id`.
  - `account_id` (service_type==aifoundry), `project_id`
    (service_type==aifoundry_project), `keyvault_id`, `search_id`,
    `cosmos_id`, `agent_storage_id` (by `agent_storage_purpose`),
    `account_storage_id` (by `account_storage_purpose`).
  - presence bools (`*_present`) — all known at plan.
  - GUID constants map (FR-046…FR-057).
  - Build `role_assignments` map + `cosmos_sql_role_assignments` map, each
    member gated on `present ∧ toggle`.
- **A-046-11** `main.tf` — `module "rbac"` with the two maps.
- **A-046-12** `check.tf` — `aifoundry_user_owned_storage_rbac_prereqs`
  (toggle ⟹ account storage resolvable ∧ both purposes set ∧ distinct) and
  `aifoundry_keyvault_connection_rbac_prereqs` (toggle ⟹ keyvault present).
- **A-046-13** `outputs.tf` — passthrough of module outputs.
- **A-046-14** `tests/` — `_fixtures` (shared mock + remote-state override),
  happy (full matrix → exact counts, VC-30/VC-32), default-off (VC-31),
  reject-user-owned-without-two-storages (VC-33),
  reject-keyvault-without-keyvault (VC-34).
- **A-046-15** `README.md`.

## CI / rollout wiring

- **A-046-16** New `.github/workflows/rbac.yml` (mirror `services.yml`): PR +
  push paths for `modules/rbac/**`, `terraform/rbac/**`,
  `variables/*/*/rbac.tfvars.json`, the workflow file; matrix runs fmt/validate/
  test for `modules/rbac` + `terraform/rbac`.
- **A-046-17** Add `rbac` to `deploy.yaml` `service` choice options.

## Verification

- **A-046-18** `terraform fmt -recursive`; `terraform init -backend=false` +
  `validate` + `test` green for `modules/rbac` and `terraform/rbac`.

## Out of scope (this engine PR)

Instance tfvars (`104`), live apply, human RBAC, CMK grants.
