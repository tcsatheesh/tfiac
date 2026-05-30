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

## Phase 8 — Hub & Spoke Vnet ↔ Private DNS Zone Links (FR-211..FR-222)

**Branch**: `004-vnet-dns-links` (off master)
**Scope**: Introduce a reusable `modules/dnslinks/` submodule emitting
`azurerm_private_dns_zone_virtual_network_link` resources per private DNS zone
exposed by the DNS stack's remote state, and wire it into `terraform/vnet/` for
both hub and spoke roles. Strictly additive — no churn on existing vnet/subnet/
NSG/route-table/firewall/bastion/peering resources (FR-222, C16.12). See
"## Amendment Plan: Hub & Spoke Vnet Links to Private DNS Zones (FR-211..FR-222)"
in [plan.md](plan.md).

### Pre-flight (verification — sequential, no code change)

- [x] T080 Verify `modules/network/outputs.tf` exports both `vnet_id` and `vnet_name` (lines 1 and 6). If either is missing, add it in this task before proceeding (FR-219, C16.9). Confirmed present at workspace inspection time — this task is a tripwire, not an edit.
- [x] T081 Verify exact DNS state-blob key from [terraform/dns/backend.tf](../../terraform/dns/backend.tf) (`hub/prd/dns.tfstate`) and capture the backend SA/RG/container values from [variables/backend.hcl](../../variables/backend.hcl) (`stcwetfstate01` / `stcwe-rg-tfs-01` / `tfstate`) for use in T103/T104 (FR-221, C16.11). Record the canonical values inline in this task before editing tfvars.
- [x] T082 Inspect [modules/dnszones/main.tf](../../modules/dnszones/main.tf) and the AVM `Azure/avm-res-network-privatednszone/azurerm ~> 0.5` source to re-confirm no externally-consumable vnet-link submodule fits the cross-stack shape; record findings in T084's README section (FR-220, C16.10, plan §2).

### Submodule scaffold — `modules/dnslinks/` (parallel-safe file creates)

- [x] T083 [P] Create [modules/dnslinks/variables.tf](../../modules/dnslinks/variables.tf) declaring: `vnet_id` (string, required), `vnet_name` (string, required), `zone_ids` (map(string), required — keys are catalogue zone keys, values are zone resource IDs), `tags` (map(string), default `{}`), `dns_subscription_id` (string, default `null` — documentation-only per plan §3) (FR-219, FR-214, C16.4, C16.9)
- [x] T084 [P] Create [modules/dnslinks/main.tf](../../modules/dnslinks/main.tf) with a single `resource "azurerm_private_dns_zone_virtual_network_link" "this"` block, `for_each = var.zone_ids`, `name = "vnetlink-${var.vnet_name}"`, `private_dns_zone_id = each.value`, `virtual_network_id = var.vnet_id`, `registration_enabled = false` (hard-coded, NOT a variable per plan §9), `tags = var.tags`. Include a comment block flagging the multi-subscription evolution path (FR-211, FR-212, FR-213, FR-216, C16.1, C16.2, C16.3, C16.6)
- [x] T085 [P] Create [modules/dnslinks/providers.tf](../../modules/dnslinks/providers.tf) declaring a `terraform.required_providers` entry for `azurerm` with an optional `configuration_aliases = [azurerm.dns]` so the root stack can pass an aliased provider (default = unaliased) per plan §3 (FR-214, C16.4)
- [x] T086 [P] Create [modules/dnslinks/outputs.tf](../../modules/dnslinks/outputs.tf) exporting `link_ids` (map of zone-key → link resource id) and `link_count` (number) for downstream assertion/visibility
- [x] T087 [P] Create [modules/dnslinks/versions.tf](../../modules/dnslinks/versions.tf) pinning the same `terraform` + `azurerm` version constraints used by `modules/network/versions.tf`
- [x] T088 [P] Create [modules/dnslinks/check.tf](../../modules/dnslinks/check.tf) with a `check "registration_disabled"` block asserting every link still has `registration_enabled == false` post-plan (defence-in-depth alongside the hard-coded literal in T084)
- [x] T089 [P] Create [modules/dnslinks/README.md](../../modules/dnslinks/README.md) opening with a "Why bare resource (Constitution IX fallback)" section citing plan §2 + FR-220 + C16.10, then documenting inputs / outputs / the aliased-provider contract (plan §3) and the `registration_enabled = false` foot-gun rationale (plan §9)

### Submodule tests — `modules/dnslinks/tests/` (parallel-safe — independent files)

- [x] T090 [P] Create [modules/dnslinks/tests/links_count_matches_zones.tftest.hcl](../../modules/dnslinks/tests/links_count_matches_zones.tftest.hcl) — `mock_provider "azurerm" {}`, pass 3 synthetic zone IDs, assert `length(azurerm_private_dns_zone_virtual_network_link.this) == 3` (FR-218 case a, C16.8 a)
- [x] T091 [P] Create [modules/dnslinks/tests/registration_disabled.tftest.hcl](../../modules/dnslinks/tests/registration_disabled.tftest.hcl) — assert every planned link has `registration_enabled == false` (FR-212, FR-218 case b, C16.2, C16.8 b)
- [x] T092 [P] Create [modules/dnslinks/tests/link_naming.tftest.hcl](../../modules/dnslinks/tests/link_naming.tftest.hcl) — assert each link's `name` equals `"vnetlink-${var.vnet_name}"` for a known vnet name input (FR-213, FR-218 case c, C16.3, C16.8 c)
- [x] T093 [P] Create [modules/dnslinks/tests/empty_zones_no_links.tftest.hcl](../../modules/dnslinks/tests/empty_zones_no_links.tftest.hcl) — pass `zone_ids = {}`, assert plan succeeds with zero `this` resources (FR-218 case d, C16.8 d, spec edge case "empty zone_ids map")

### Root-stack wiring — `terraform/vnet/` (sequential — shared variables/main)

- [x] T094 Add `variable "dns_state_backend"` to [terraform/vnet/variables.tf](../../terraform/vnet/variables.tf) as an `object({ subscription_id, resource_group_name, storage_account_name, container_name, key })` with all five fields `string`, no `optional`. Mirror the structure of `var.hub_state_backend`. Add a `validation` block asserting `endswith(var.dns_state_backend.key, ".tfstate")` (defence-in-depth) (FR-221, C16.11, plan §4)
- [x] T095 Create [terraform/vnet/dns.tf](../../terraform/vnet/dns.tf) holding (a) an unconditional `data "terraform_remote_state" "dns"` block sourced from `var.dns_state_backend` (no `count` — both hub and spoke need it per C16.1), and (b) a `module "dnslinks"` invocation passing `vnet_id = module.network.vnet_id`, `vnet_name = module.network.vnet_name`, `zone_ids = data.terraform_remote_state.dns.outputs.zone_ids`, `tags = {}` (until T096 wires real tags). DO NOT touch `main.tf` — keep DNS-cross-stack concern visually isolated per plan §5 (FR-215, FR-219, C16.5, C16.9)
- [x] T096 Expose a `vnet_tags` output from [modules/network/outputs.tf](../../modules/network/outputs.tf) returning `module.naming.names[local.vnet_canonical_name].tags`, then update the `module "dnslinks"` call in `terraform/vnet/dns.tf` to pass `tags = module.network.vnet_tags`. Keeps tag provenance consistent with every other resource in the network module
- [x] T097 Update [terraform/vnet/providers.tf](../../terraform/vnet/providers.tf) to declare an aliased provider `azurerm.dns` configured with `subscription_id = var.dns_state_backend.subscription_id` (v1: identical to default subscription; documented as forward-compat per plan §3). Pass `providers = { azurerm.dns = azurerm.dns }` from the `module "dnslinks"` call in `terraform/vnet/dns.tf` (FR-214, C16.4)

### Root-stack tests — `terraform/vnet/tests/` (mostly parallel-safe — separate files)

- [x] T098 Extend [terraform/vnet/tests/_fixtures.tftest.hcl](../../terraform/vnet/tests/_fixtures.tftest.hcl) to add a reusable `dns_state_backend` default variables block AND a reusable mocked `data.terraform_remote_state.dns` outputs payload (one-zone synthetic `zone_ids` map) using `override_data`. Every downstream test inherits this — no per-file duplication required (plan §7)
- [x] T099 Create [terraform/vnet/tests/dnslinks_remote_state_wiring.tftest.hcl](../../terraform/vnet/tests/dnslinks_remote_state_wiring.tftest.hcl) — two `run` blocks (`role = "hub"` and `role = "spoke"`) mocking `data.terraform_remote_state.dns` with a 2-zone `zone_ids` output; assert `module.dnslinks` plans exactly 2 link resources in each (FR-211, FR-215, plan §7)
- [x] T100 [P] Extend [terraform/vnet/tests/plan_zero_diff_hub.tftest.hcl](../../terraform/vnet/tests/plan_zero_diff_hub.tftest.hcl) to inherit the T098 DNS mock and re-assert zero-diff with the new `module.dnslinks` in the graph (FR-217, FR-222, C16.7, C16.12)
- [x] T101 [P] Extend [terraform/vnet/tests/plan_zero_diff_spoke.tftest.hcl](../../terraform/vnet/tests/plan_zero_diff_spoke.tftest.hcl) symmetrically for the spoke role (FR-217, C16.7)
- [x] T102 Audit every other `*.tftest.hcl` under [terraform/vnet/tests/](../../terraform/vnet/tests/) and add the inherited T098 DNS mock to any file that breaks because `var.dns_state_backend` is now required (additive only; no rewrites)

### Tfvars wiring (parallel-safe — independent files)

- [x] T103 [P] Add a top-level `dns_state_backend` block to [variables/hub/npd/vnet.tfvars.json](../../variables/hub/npd/vnet.tfvars.json) with `subscription_id = "883c9081-23ed-4674-95c5-45c74834e093"`, `resource_group_name = "stcwe-rg-tfs-01"`, `storage_account_name = "stcwetfstate01"`, `container_name = "tfstate"`, `key = "hub/prd/dns.tfstate"` (values verified in T081) (FR-221, C16.11)
- [x] T104 [P] Add the same `dns_state_backend` block to [variables/sp01/npd/vnet.tfvars.json](../../variables/sp01/npd/vnet.tfvars.json) — identical values; the DNS state lives in the hub regardless of consumer (FR-221, C16.11)

### Format & test gate (sequential)

- [x] T105 Run `terraform fmt -recursive modules/dnslinks modules/network terraform/vnet` — must be clean (zero diff)
- [x] T106 Run `terraform test` in `modules/dnslinks/` — all 4 tests GREEN (FR-218, C16.8)
- [x] T107 Run `terraform test` in `modules/network/` — must remain GREEN (regression check for T096 output addition)
- [x] T108 Run `terraform test` in `terraform/vnet/` — all existing + T099/T100/T101 tests GREEN (FR-217, FR-222, C16.7, C16.12)
- [x] T109 SC audit: `grep -RIn 'resource "azurerm_\|resource "azapi_' modules/dnslinks | grep -v ".terraform/"` returns exactly one resource (`azurerm_private_dns_zone_virtual_network_link.this`) — no AVM module call, no telemetry stack (plan §2 sanity)
- [x] T110 Mark T080–T109 `[X]`, commit, push, open PR `004-vnet-dns-links → master`, squash-merge, prune branch

### Live rollout — hub/npd (sequential, post-merge on master)

- [x] T111 Open state SA firewall on `stcwetfstate01`: `publicNetworkAccess=Enabled`, add operator public IP rule (record IP in PR comment for audit)
- [x] T112 `cd terraform/vnet && terraform init -reconfigure -backend-config=../../variables/backend.hcl -backend-config="key=hub/npd/vnet.tfstate"`
- [x] T113 `terraform plan -no-color -input=false -var-file=../../variables/hub/npd/vnet.tfvars.json -var subscription_id=883c9081-23ed-4674-95c5-45c74834e093 -out=hub.npd.tfplan`
- [x] T114 **GATE per FR-222 / C16.12**: inspect plan summary. MUST be `Plan: N to add, 0 to change, 0 to destroy.` where every "add" line is either `data.terraform_remote_state.dns` (read) or `module.dnslinks.azurerm_private_dns_zone_virtual_network_link.this[...]`. ABORT and revert if any other change appears against pre-existing vnet/subnet/NSG/route-table/firewall/bastion/peering resources
- [x] T115 `terraform apply hub.npd.tfplan` — confirm exit 0 and N link resources created
- [x] T116 Restore state SA firewall: `publicNetworkAccess=Disabled`, `defaultAction=Deny`, remove temp operator IP rule (CLAUDE.md autonomy rule)

### Live verification (sequential)

- [x] T117 From operator workstation, validate in-vnet private resolution via the build VM:
  ```bash
  az vm run-command invoke \
    -g rg-bld-shd-hub-npd-swc-001 \
    -n vm-bld-shd-hub-npd-swc-001 \
    --subscription 883c9081-23ed-4674-95c5-45c74834e093 \
    --command-id RunShellScript \
    --scripts "set -e; nslookup -type=SOA privatelink.blob.core.windows.net 168.63.129.16; nslookup -type=SOA privatelink.vaultcore.azure.net 168.63.129.16"
  ```
  Acceptance: both SOA queries return an authority anchored at `azureprivatedns.net`, proving the vnet resolver now consults the linked private zones (per plan §8 step 4). NXDOMAIN on A-record lookups for non-provisioned hosts is expected and fine — the SOA authority is the contract
- [x] T118 Report plan summary (N adds), apply duration, and SOA query output back to user; mark Phase 8 complete

> Phase 8 tasks track spec FR-211..FR-222 and clarifications C16.1..C16.12, and execute plan amendment §1–§9. Dependency chain: T080–T082 (verify) → T083–T089 (submodule scaffold, parallel) → T090–T093 (submodule tests, parallel) → T094 → T095 → T096 → T097 (root wiring, sequential) → T098 → T099/T100/T101/T102 (root tests, T100/T101 parallel) → T103/T104 (tfvars, parallel) → T105 → T106 → T107 → T108 → T109 → T110 (gate + merge) → T111…T116 (rollout, sequential) → T117 → T118 (verify + report).

## Phase 9 — Amendment 2 — Drift reconciliation (FR-223..FR-225)

- [x] T119 `modules/network/firewall/main.tf` — add `ip_tags = { FirstPartyUsage = "/Unprivileged" }` to BOTH `module "pip_data"` and `module "pip_mgmt"` (FR-223). *Done — sourced from local `first_party_pip_ip_tags`.*
- [x] T120 [P] `modules/network/bastion/variables.tf` — add optional input `public_ip_tags` (`map(string)`, default `{}`).
- [x] T121 [P] `modules/network/bastion/outputs.tf` — add output `public_ip_id` exposing the new in-module PIP id (informational).
- [x] T122 `modules/network/bastion/main.tf` — add `module "pip"` (AVM publicipaddress) with `ip_tags = { FirstPartyUsage = "/Unprivileged" }`; switch the existing `module "bastion"` `ip_configuration` to `create_public_ip = false` + `public_ip_address_id = module.pip.public_ip_id` (FR-224).
- [x] T123 `modules/network/main.tf` — in the wrapper's `module "bastion"` block, add `public_ip_tags = module.naming.names[local.pip_canonical_names.bas].tags` so the new PIP keeps engine-derived tags.
- [x] T124 `modules/network/locals.tf` — add `storage_se_locations = { swedencentral = ["swedencentral", "swedensouth"] }` (FR-225 / C16.16).
- [x] T125 `modules/network/main.tf` — rewrite the `service_endpoints_with_location` for-expression to emit `lookup(local.storage_se_locations, local.region_full, ["*"])` for `Microsoft.Storage` and `["*"]` otherwise.
- [x] T126 `terraform fmt -recursive` — clean.
- [x] T127 `cd modules/network && terraform init -backend=false && terraform validate` — green.
- [x] T128 `cd terraform/vnet && rm -rf .terraform && terraform init -backend=false && terraform validate` — green.
- [x] T129 [P] Add `terraform/vnet/tests/pip_ip_tags_present.tftest.hcl` — asserts `module.network.firewall_pip_ip_tags["FirstPartyUsage"] == "/Unprivileged"` and same for `bastion_pip_ip_tags` (new wrapper outputs back-sourced from each submodule's `local.first_party_pip_ip_tags`, which is the single source of truth wired into the PIP modules).
- [x] T130 [P] Add `terraform/vnet/tests/subnet_storage_endpoint_regional.tftest.hcl` — asserts the `dev` and `pre-production` subnets emit `Microsoft.Storage` with locations `["swedencentral","swedensouth"]` via new wrapper output `subnet_service_endpoints`, and `Microsoft.KeyVault` with `["*"]`; asserts `buildsvr` emits zero endpoints. Uses length-of-filtered-list pattern for terraform 1.9.8 short-circuit-free `for` parity.
- [x] T131 `cd terraform/vnet && terraform test` — all green (17/17 on both terraform 1.9.8 and 1.13.4).
- [x] T132 `cd modules/network && terraform test` — all green (11/11 on both terraform 1.9.8 and 1.13.4).
- [ ] T133 Commit on branch `004-vnet-drift-reconcile`, push, open PR against master. CI MUST be fully green.
- [ ] T134 Squash-merge PR; delete remote+local branch; checkout master + pull.

### Phase 9 live rollout (post-merge)

- [x] T135 Open SA firewall on `stcwetfstate01` to operator IP (mirror T111).
- [x] T136 `cd terraform/vnet && rm -rf .terraform && terraform init -reconfigure -backend-config=../../variables/backend.hcl -backend-config="key=hub/npd/vnet.tfstate"`.
- [x] T137 **State migration (C16.18)**: `terraform state mv 'module.network.module.bastion[0].module.bastion.module.public_ip_address[0].azurerm_public_ip.this' 'module.network.module.bastion[0].module.pip.azurerm_public_ip.this'`.
- [x] T138 `terraform plan -no-color -input=false -var-file=../../variables/hub/npd/vnet.tfvars.json -var subscription_id=883c9081-23ed-4674-95c5-45c74834e093 -out=hub.npd.tfplan`.
- [x] T139 **GATE per FR-222**: plan summary MUST be `No changes. Your infrastructure matches the configuration.` OR `Plan: 25 to add, 0 to change, 0 to destroy.` where the 25 adds are exclusively `module.dnslinks.azurerm_private_dns_zone_virtual_network_link.this[*]` carried over from Phase 8. ABORT and `terraform state mv` BACK if any other change appears.
- [x] T140 If gate passes AND adds == 25 dnslinks (Phase 8 not yet applied), `terraform apply hub.npd.tfplan` — this completes Phase 8's apply with drift fixed; otherwise (gate green with zero adds), skip apply.
- [x] T141 Restore SA firewall lock (mirror T116).
- [x] T142 If T140 applied: validate per Phase 8 T117 (build VM nslookup SOA); otherwise skip.
- [x] T143 Report plan summary and Phase 9 complete.

> Phase 9 tasks track spec FR-223..FR-225 and clarifications C16.13..C16.18, and execute plan amendment §10–§14. Dependency chain: T119 (firewall) → T120/T121 (bastion vars+outputs, parallel) → T122 → T123 → T124 → T125 → T126 → T127 → T128 → T129/T130 (tests, parallel) → T131 → T132 → T133 → T134 → T135 → T136 → T137 → T138 → T139 → T140 → T141 → T142 → T143.
