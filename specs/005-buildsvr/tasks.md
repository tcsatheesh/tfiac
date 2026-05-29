# Tasks — 005-buildsvr

## Phase 1 — Wrapper module scaffolding

- [ ] T001 `modules/buildsvr/versions.tf` (required_providers passthrough)
- [ ] T002 `modules/buildsvr/variables.tf` (input, vm_sku, image, ssh key, sizes, runner config, identity role assignments, subnet_resource_id, log_workspace_resource_id, zone, disable_password_authentication, custom_data_override)
- [ ] T003 `modules/buildsvr/locals.tf` (engine services, derived names)
- [ ] T004 `modules/buildsvr/main.tf` (naming + RG + VM AVM)
- [ ] T005 `modules/buildsvr/cloud-init.yaml.tpl`
- [ ] T006 `modules/buildsvr/outputs.tf`
- [ ] T007 `modules/buildsvr/check.tf` (BLD-INV-6/7/8/9)
- [ ] T008 `modules/buildsvr/README.md`

## Phase 2 — Root stack

- [ ] T009 `terraform/buildsvr/versions.tf`
- [ ] T010 `terraform/buildsvr/providers.tf`
- [ ] T011 `terraform/buildsvr/backend.tf`
- [ ] T012 `terraform/buildsvr/variables.tf` (BLD-INV-1..4, vm_sku, ssh key, runner config, state-backend descriptors, *_state_override test hooks)
- [ ] T013 `terraform/buildsvr/locals.tf` (naming_input with stack_purpose="bld")
- [ ] T014 `terraform/buildsvr/main.tf` (remote state lookups, module call, check.subscription_pinned)
- [ ] T015 `terraform/buildsvr/outputs.tf`
- [ ] T016 `terraform/buildsvr/README.md`

## Phase 3 — Day-one tfvars

- [ ] T017 `variables/hub/npd/buildsvr.tfvars.json` (subscription, tenant=hub, region=swc, env=npd, vm_sku=Standard_D4s_v5, runner config, state-backend descriptors for vnet+log)

## Phase 4 — Tests

- [ ] T018 `modules/buildsvr/tests/_fixtures.tftest.hcl` (canonical variables + mock_providers)
- [ ] T019 `modules/buildsvr/tests/positive_baseline.tftest.hcl` (vm name snapshot)
- [ ] T020 `modules/buildsvr/tests/runner_token_absent.tftest.hcl`
- [ ] T021 `modules/buildsvr/tests/fixtures/vm_name_snapshot.json`
- [ ] T022 `terraform/buildsvr/tests/plan_snapshot.tftest.hcl`
- [ ] T023 `terraform/buildsvr/tests/subscription_mismatch.tftest.hcl`
- [ ] T024 `terraform/buildsvr/tests/region_drift.tftest.hcl`
- [ ] T025 `terraform/buildsvr/tests/password_auth_negative.tftest.hcl`

## Phase 5 — Quality

- [ ] T026 `terraform fmt -recursive`
- [ ] T027 `terraform -chdir=modules/buildsvr init -backend=false && terraform -chdir=modules/buildsvr test`
- [ ] T028 `terraform -chdir=terraform/buildsvr init -backend=false && terraform -chdir=terraform/buildsvr test`
- [ ] T029 Commit, push, PR, squash-merge
- [ ] T030 Live apply to hub/npd

## Analyze

Self-review prior to T029:
- All FR-501..FR-517 covered by code or test
- All BLD-INV-1..10 enforced
- No hard-coded values that should be tfvars
- AVM-only (no bare `azurerm_*`)
- `terraform fmt` clean, `terraform test` green
