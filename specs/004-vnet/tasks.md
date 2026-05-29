# Tasks — Feature 004 — Hub & Spoke Network Foundation

Spec: [spec.md](spec.md) | Plan: [plan.md](plan.md) | Data model: [data-model.md](data-model.md) | Contracts: [contracts/network-stack.md](contracts/network-stack.md)

Legend: `[P]` = parallelisable with other `[P]` in the same phase. Sequential otherwise.

## Phase 1 — Setup

- [X] T001 Create `modules/network/` skeleton (empty dir + `tests/`, `tests/fixtures/`)
- [X] T002 [P] Create `terraform/vnet/` skeleton (empty dir + `tests/`)
- [X] T003 [P] Create `variables/npd/hub/` and `variables/npd/sp01/` dirs
- [X] T004 [P] `terraform/vnet/versions.tf` — provider pins (D12)
- [X] T005 [P] `terraform/vnet/backend.tf` — azurerm + `use_azuread_auth = true`
- [X] T006 [P] `terraform/vnet/providers.tf` — single `azurerm` provider with `subscription_id`
- [X] T007 [P] `modules/network/providers.tf` — required_providers passthrough only

## Phase 2 — Foundational

### Wrapper module `modules/network/`

- [X] T008 `modules/network/variables.tf` — 9 inputs per data-model
- [X] T009 `modules/network/locals.tf` — `role_catalogue`, `engine_services`, `engine_children`, computed canonical names
- [X] T010 `modules/network/main.tf` — `module "naming"` + `module "rg"` + `module "vnet"` + per-role NSG + RT
- [X] T011 `modules/network/check.tf` — VNET-INV-3, -5, -8, -9, -10 preconditions
- [X] T012 `modules/network/outputs.tf` — outputs per data-model
- [X] T013 `modules/network/bastion/{providers,variables,main,outputs}.tf` — AVM bastion + 1× PIP
- [X] T014 `modules/network/firewall/{providers,variables,main,outputs}.tf` — AVM firewall + 2× PIP + empty policy
- [X] T015 `modules/network/peering/{providers,variables,main,outputs,README}.tf` — provider-aliased ×2 peering (Constitution IX exception)
- [X] T016 Wire bastion + firewall submodules into `modules/network/main.tf` via `count = var.role=="hub" ? 1 : 0`
- [X] T017 Wire peering submodule into root stack (not wrapper) — see Phase 2 root stack

### Root stack `terraform/vnet/`

- [X] T018 `terraform/vnet/variables.tf` — 11 inputs per data-model
- [X] T019 `terraform/vnet/locals.tf` — naming_input bundle (`stack_purpose="net"`)
- [X] T020 `terraform/vnet/main.tf` — `data "azurerm_client_config"`, `check "subscription_match"`, optional `data "terraform_remote_state" "hub"`, `module "network"`, conditional `module "peering"`
- [X] T021 `terraform/vnet/outputs.tf` — 1:1 re-export
- [X] T022 `terraform/vnet/check.tf` — VNET-INV-6, -7 (defence in depth)

### tfvars

- [X] T023 [P] `variables/npd/hub/vnet.tfvars.json` — address_space + 7 subnets + role=hub
- [X] T024 [P] `variables/npd/sp01/vnet.tfvars.json` — address_space + 6 subnets + role=spoke + hub_state_backend

### Gate

- [X] T025 `terraform init -backend=false && terraform validate` GREEN in `modules/network/`, `modules/network/bastion/`, `modules/network/firewall/`, `modules/network/peering/`, `terraform/vnet/`

## Phase 3 — US1: hub deployment

### Tests

- [X] T026 [P] `modules/network/tests/_fixtures.tftest.hcl` — reference hub variables + mock_provider × 5
- [X] T027 [P] `terraform/vnet/tests/_fixtures.tftest.hcl` — reference root vars + mock_provider × 5
- [X] T028 [P] `modules/network/tests/positive_baseline_hub.tftest.hcl` — snapshot match
- [X] T029 [P] `modules/network/tests/bastion_required_on_hub.tftest.hcl` — `expect_failures = [terraform_data.assertions]`
- [X] T030 [P] `modules/network/tests/firewall_required_on_hub.tftest.hcl`
- [X] T031 [P] `modules/network/tests/unknown_role_rejected.tftest.hcl` — `expect_failures = [var.role]`
- [X] T032 [P] `modules/network/tests/address_space_empty_rejected.tftest.hcl` — `expect_failures = [var.address_space]`
- [X] T033 [P] `terraform/vnet/tests/wrong_region.tftest.hcl`
- [X] T034 [P] `terraform/vnet/tests/wrong_role.tftest.hcl`
- [X] T035 [P] `terraform/vnet/tests/subscription_mismatch.tftest.hcl`
- [X] T036 [P] `terraform/vnet/tests/hub_with_hub_backend_rejected.tftest.hcl`
- [X] T037 [P] `terraform/vnet/tests/plan_zero_diff_hub.tftest.hcl`
- [X] T038 [P] `terraform/vnet/tests/plan_snapshot_hub.tftest.hcl`

### Snapshot fixtures

- [X] T039 [P] `modules/network/tests/fixtures/vnet_name_snapshot_hub.json` = `"vnet-net-shd-hub-npd-swc-001"`
- [X] T040 [P] `modules/network/tests/fixtures/rg_name_snapshot.json` = `"rg-net-shd-<tenant>-<env>-swc-001"`
- [X] T041 [P] `modules/network/tests/fixtures/README.md`

### Gate

- [X] T042 `terraform test` GREEN in `modules/network/` AND `terraform/vnet/` for the hub-scoped subset

## Phase 4 — US2: spoke deployment

### Tests

- [X] T043 [P] `modules/network/tests/positive_baseline_spoke.tftest.hcl`
- [X] T044 [P] `modules/network/tests/fixtures/vnet_name_snapshot_spoke.json` = `"vnet-net-shd-sp01-npd-swc-001"`
- [X] T045 [P] `terraform/vnet/tests/spoke_missing_hub_backend.tftest.hcl` — `expect_failures = [terraform_data.assertions]`
- [X] T046 [P] `terraform/vnet/tests/plan_zero_diff_spoke.tftest.hcl`
- [X] T047 [P] `terraform/vnet/tests/plan_snapshot_spoke.tftest.hcl`

Spoke tests need `override_data` on `data.terraform_remote_state.hub` to supply synthetic `vnet_id`, `vnet_name`, `firewall_private_ip`.

### Gate

- [X] T048 `terraform test` GREEN across all wrapper module + root stack tests

## Phase 5 — Polish

- [X] T049 [P] `modules/network/README.md` — inputs/outputs/hard-fails/role catalogue/AVM pins/snapshot fixtures
- [X] T050 [P] `modules/network/bastion/README.md`
- [X] T051 [P] `modules/network/firewall/README.md`
- [X] T052 [P] `modules/network/peering/README.md` (Constitution IX exception narrative)
- [X] T053 [P] `terraform/vnet/README.md` — quickstart for both stacks
- [X] T054 [P] `.github/workflows/vnet.yml` — fmt / init / validate / test matrix
- [X] T055 SC audit: `grep -RIn 'resource "azurerm_\|resource "azapi_' modules/network terraform/vnet | grep -v ".terraform/"` returns only the 2 expected peering resources
- [X] T056 `terraform fmt -recursive modules/network terraform/vnet` clean
- [X] T057 Final `terraform test` GREEN in both dirs
- [X] T058 Mark all tasks `[X]`, commit, push, PR to master, merge, prune
