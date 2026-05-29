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

## Phase 6 — Amendment: configurable hub firewall SKU (FR-209)

**Branch**: `004-vnet-firewall-sku` (off master)
**Scope**: Parameterise the hub firewall + firewall policy SKU tier; default
preserved as `Standard`; `variables/hub/npd/vnet.tfvars.json` opts into `Basic`.
See "## Amendment plan — FR-209 firewall SKU" in [plan.md](plan.md).

### Implementation (sequential — shared files within each module)

- [X] T059 Add `variable "firewall_sku_tier"` to `modules/network/firewall/variables.tf` — type `string`, default `"Standard"`, validation `contains(["Basic","Standard","Premium"], var.firewall_sku_tier)`
- [X] T060 Wire `var.firewall_sku_tier` into both `azurerm_firewall_policy.this.sku` and `module.firewall.firewall_sku_tier` (AVM `Azure/avm-res-network-azurefirewall/azurerm`) in `modules/network/firewall/main.tf`
- [X] T061 Add wrapper-level `variable "firewall_sku_tier"` (same validation + default) to `modules/network/variables.tf` and forward it to `module.firewall` in `modules/network/main.tf`
- [X] T062 Add root-stack `variable "firewall_sku_tier"` (same validation + default) to `terraform/vnet/variables.tf` and forward to `module.network` in `terraform/vnet/main.tf`
- [X] T063 Set `"firewall_sku_tier": "Basic"` in `variables/hub/npd/vnet.tfvars.json` (spoke tfvars unchanged — spokes do not own the firewall)

### Tests (independent files)

- [X] T064 [P] Create `modules/network/tests/firewall_sku_basic.tftest.hcl` — plan-only run with `role = "hub"` and `firewall_sku_tier = "Basic"`; assert plan succeeds against mocked providers
- [X] T065 [P] Create `modules/network/tests/firewall_sku_invalid.tftest.hcl` — `expect_failures = [var.firewall_sku_tier]` for value `"Free"`
- [X] T065a [P] Create `terraform/vnet/tests/firewall_sku_basic_hub.tftest.hcl` — plan-only hub run with `firewall_sku_tier = "Basic"` against mocked providers, asserts root forwarding works end-to-end

### Gate

- [X] T066 `terraform fmt -recursive modules/network terraform/vnet` clean
- [X] T067 `terraform test` GREEN in `modules/network/` AND `terraform/vnet/`. Existing hub snapshot tests (`positive_baseline_hub.tftest.hcl`, `plan_snapshot_hub.tftest.hcl`, `plan_zero_diff_hub.tftest.hcl`) must remain green — they inline their own `variables` block and do not load `variables/hub/npd/vnet.tfvars.json`, so T063 does not affect them.
- [X] T068 Mark T059–T067 `[X]`, commit, push, open PR `004-vnet-firewall-sku → master`, merge, prune branch
- [X] T069 (post-merge, on master) Roll out Basic SKU to hub/npd:
  1. Open state SA firewall (publicNetworkAccess=Enabled, add CI/operator IP)
  2. `terraform plan -no-color -input=false -var-file=../../variables/hub/npd/vnet.tfvars.json -var subscription_id=<sub> -out=hub.npd.tfplan`
  3. Inspect plan: confirm `azurerm_firewall_policy.this` and the AVM firewall resource show `-/+ destroy and then create replacement`; the data PIP, mgmt PIP, AzureFirewallSubnet, and route table must NOT be replaced
  4. `terraform apply hub.npd.tfplan` (accept brief hub data-plane outage per C14.3)
  5. Verify post-apply: `terraform output firewall_private_ip` is still `10.240.5.4` (or note new value)
  6. If `firewall_private_ip` changed, run `terraform apply` on every spoke stack to refresh the RT next-hop
  7. Restore state SA firewall (publicNetworkAccess=Disabled, defaultAction=Deny, remove temp IP)
  8. Report SKU change, outage duration, and any spoke re-applies

## Phase 7 — Amendment: hub default route (FR-210)

**Branch**: `004-vnet-egress` (off master)
**Scope**: Make the hub route table emit `0.0.0.0/0 → in-vnet firewall private IP`
by default so hub workload subnets (notably `buildsvr`, which has
`defaultOutboundAccess=false`) can reach internet package repos through the
firewall. Unblocks feature 005 cloud-init (apt → azure.archive.ubuntu.com,
aka.ms, packages.microsoft.com, github.com). See C15 in [spec.md](spec.md).

### Implementation (sequential — shared files within each module)

- [X] T070 Extend the `routes = …` ternary in `module "rt"` (`modules/network/main.tf`) to add a hub branch that emits `0.0.0.0/0 → module.firewall[0].private_ip` when `var.role == "hub" && var.enable_hub_default_route`
- [X] T071 Add `variable "enable_hub_default_route"` (bool, default `true`) to `modules/network/variables.tf` with hub-only docstring
- [X] T072 Add `variable "enable_hub_default_route"` (bool, default `true`) to `terraform/vnet/variables.tf` and forward it to `module.network` in `terraform/vnet/main.tf`

### Tests (independent files)

- [X] T073 [P] Create `modules/network/tests/hub_default_route.tftest.hcl` — two plan runs against mocked providers: (a) default (enabled), (b) opt-out `enable_hub_default_route = false`. Both must plan green and emit the canonical `rt-net-shd-hub-npd-swc-001` name. Existing hub snapshot tests must remain green (they don't assert route content)

### Gate

- [X] T074 `terraform fmt -recursive modules/network terraform/vnet` clean
- [X] T075 `terraform test` GREEN in `modules/network/` AND `terraform/vnet/`
- [X] T076 Mark T070–T075 `[X]`, commit, push, open PR `004-vnet-egress → master`, merge, prune branch
- [X] T077 (post-merge, on master) Roll out to hub/npd:
  1. Open state SA firewall (publicNetworkAccess=Enabled, add operator IP `86.28.117.247`)
  2. `cd terraform/vnet && terraform init -reconfigure -backend-config="..."` for hub/npd
  3. `terraform plan -no-color -input=false -var-file=../../variables/hub/npd/vnet.tfvars.json -var subscription_id=883c9081-23ed-4674-95c5-45c74834e093 -out=hub.npd.tfplan`
  4. Inspect plan: confirm `module.network.module.rt.azurerm_route_table.this` (or `azurerm_route.this["to-firewall"]`) shows a single in-place add of `udr-defaultroute` 0.0.0.0/0 → 10.240.5.4. No other resources should change.
  5. `terraform apply hub.npd.tfplan`
  6. Restore state SA firewall (publicNetworkAccess=Disabled, defaultAction=Deny, remove temp IP)
- [X] T078 Re-bootstrap the build VM to validate egress unblocked. From operator workstation:
  ```bash
  az vm run-command invoke \
    -g rg-bld-shd-hub-npd-swc-001 \
    -n vm-bld-shd-hub-npd-swc-001 \
    --subscription 883c9081-23ed-4674-95c5-45c74834e093 \
    --command-id RunShellScript \
    --scripts "set -e; apt-get update -y; apt-get install -y curl jq ca-certificates apt-transport-https lsb-release gnupg; /opt/buildsvr/bootstrap.sh; az --version | head -1"
  ```
  Acceptance: `az --version` returns a version banner (Azure CLI installed) and `/var/log/buildsvr-bootstrap.log` shows the GitHub runner archive downloaded + extracted.
- [X] T079 Report SKU/route change, plan summary, and `az --version` output back to user.

> Phase 7 tasks complete and consistent with spec FR-210 + C15.1–C15.11 and plan amendment.
