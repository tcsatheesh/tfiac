# Plan — Feature 104 (sp01/dev RBAC instance)

## Approach

Instance-only. Author a single tfvars file
([variables/sp01/dev/rbac.tfvars.json](../../variables/sp01/dev/rbac.tfvars.json))
that parameterizes the existing 007-rbac engine (`terraform/rbac/` +
`modules/rbac/`). No engine module/stack code changes.

## Technical context

- **Engine**: 007-rbac — `terraform/rbac/` reads the 006-services remote
  state, resolves the account/project managed identities + their target
  resource scopes, and fans the grants out through `modules/rbac/`
  (`azurerm_role_assignment` for control-plane + `azapi_resource` for the
  Cosmos SQL data-plane role).
- **Upstream state**: `sp01/dev/services.tfstate` (103-sp01-dev-services) in
  the hub state account `rg-tfs-shd-hub-npd-swc-001` /
  `sttfsshdhubnpdswc001` / `tfstate`.
- **Backend state key**: `sp01/dev/rbac.tfstate` (supplied by `deploy.yaml`
  as `<tenant>/<environment>/<service>.tfstate`).
- **subscription_id**: injected by `deploy.yaml`; placeholder in tfvars.

## Steps

- Create [variables/sp01/dev/rbac.tfvars.json](../../variables/sp01/dev/rbac.tfvars.json):
  `services_state_backend` -> `sp01/dev/services.tfstate`;
  `enable_aifoundry_user_owned_storage=true`;
  `enable_aifoundry_keyvault_connection=true`;
  `agent_storage_purpose=agt`; `account_storage_purpose=act` (must match the
  103 services tfvars — FR-104-03).
- No engine (`007-rbac`) or module change.
- Validate with `terraform validate -backend=false` + `terraform test` on
  `terraform/rbac` (5 stack + 2 module cases stay green).
- Confirm `.github/workflows/rbac.yml` already watches the tfvars path and
  `deploy.yaml` already lists `rbac` as a `service` option (both true after
  the 007-rbac engine PR).

## Validation

- `terraform validate` on `terraform/rbac` ✅
- Engine `terraform test` 5/5 (stack) + 2/2 (module) green ✅
- tfvars JSON valid; every key a known engine variable.

## Rollout

- Workflow only, AFTER the 103 services deployment exists:
  `gh workflow run deploy.yaml -f service=rbac -f tenant=sp01 -f environment=dev -f action=apply -f apply=true`.
- **Prepare-only for this change set — no deploy dispatched.**

## Amendment plan — FR-104-05 project-MI AcrPull opt-in (2026-06-05)

- Edit only [variables/sp01/dev/rbac.tfvars.json](../../variables/sp01/dev/rbac.tfvars.json):
  add `enable_project_acr_pull: true`. No engine (`007-rbac`) or module change —
  the grant capability is the already-merged FR-064 engine toggle.
- **Why.** A private project's Hosted-Agent `create_agent` returns 503 without
  AcrPull on the registry for the project MI. The engine emits the
  `project-acr-pull` grant when the toggle is on; the gate (project +
  container_registry present in services state) is already satisfied by 103.
- **Paired with 103 FR-103-12** (project ContainerRegistry connection / engine
  FR-063). Rollout order is `services` (connection) then `rbac` (grant).
- **Verification (no live apply locally).** `terraform fmt -recursive` clean;
  `terraform validate -backend=false` + `terraform test` on `terraform/rbac`
  green (engine unchanged).
- **Rollout** via the GitHub `deploy` workflow only (`service=rbac`), AFTER the
  103 `services` apply. Never a local apply.
