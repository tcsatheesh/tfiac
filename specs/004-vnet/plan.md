# Plan — Feature 004 — Hub & Spoke Network Foundation

**Spec**: [spec.md](spec.md) | **Status**: draft → implementation on branch `004-vnet`

## Tech Stack

- Terraform `~> 1.9`
- Providers (root): `azurerm ~> 4.0`, `azapi ~> 2.4`, `modtm ~> 0.3`, `random ~> 3.5`, `time ~> 0.13`
- AVM modules (per [Clarification C2](spec.md#clarifications)):
  - `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`
  - `Azure/avm-res-network-virtualnetwork/azurerm ~> 0.8` (vnet + subnets + intra-stack peerings)
  - `Azure/avm-res-network-networksecuritygroup/azurerm ~> 0.4`
  - `Azure/avm-res-network-routetable/azurerm ~> 0.3`
  - `Azure/avm-res-network-bastionhost/azurerm ~> 0.4`
  - `Azure/avm-res-network-azurefirewall/azurerm ~> 0.4`
  - `Azure/avm-res-network-publicipaddress/azurerm ~> 0.2`
- Naming engine: `../naming` (catalogue already provides `vnet`, `subnet`, `nsg`, `route_table`, `vnet_bastion`, `vnet_firewall`, `public_ip`, `route`, `nsg_rule`, `resource_group` rows — **no engine changes**)
- State backend: `azurerm` with `use_azuread_auth = true`; state path `<scope>/<env>/vnet.tfstate`
- Identity: `TF_VAR_subscription_id` + `TF_VAR_repo` from `.env`
- CI: `.github/workflows/vnet.yml` — fmt / init -backend=false / validate / test for all wrapper modules + root stack

## Architecture

```
modules/network/                # wrapper aggregating vnet+subnets+nsgs+rt
  ├── main.tf, locals.tf, variables.tf, outputs.tf, providers.tf, check.tf
  ├── bastion/                  # hub-only sub-module (AVM bastion + PIP)
  ├── firewall/                 # hub-only sub-module (AVM firewall + 2× PIP + policy)
  └── peering/                  # spoke-only sub-module (provider-aliased)
terraform/vnet/                 # single generic root stack; switches via var.role
variables/npd/hub/vnet.tfvars.json
variables/npd/sp01/vnet.tfvars.json
.github/workflows/vnet.yml
```

## Module-internal Subnet Role Catalogue

A `local.role_catalogue` map (in `modules/network/locals.tf`) decides per-role:
NSG required? Route table attached? Default service endpoints, default
delegation, Azure-mandated literal name (for bastion / firewall /
firewall-mgmt). Caller passes only `{ role => cidr }` per [FR-201] /
[FR-202] / spec § Subnet role catalogue.

| Role | NSG | RT | Service endpoints | Delegation | Literal name |
|---|---|---|---|---|---|
| `development` | yes | yes | Storage, KeyVault | — | engine-named |
| `pre-production` | yes | yes | Storage, KeyVault | — | engine-named |
| `api-management` | yes | no | — | — | engine-named |
| `buildsvr` | yes | yes | — | — | engine-named |
| `function-app` | yes | yes | — | `Microsoft.Web/serverFarms` | engine-named |
| `logic-app` | yes | yes | — | `Microsoft.Web/serverFarms` | engine-named |
| `preprod-func` | yes | yes | — | `Microsoft.Web/serverFarms` | engine-named |
| `preprod-logic` | yes | yes | — | `Microsoft.Web/serverFarms` | engine-named |
| `bastion` | yes (AVM defaults) | no | — | — | `AzureBastionSubnet` |
| `firewall` | no | no | — | — | `AzureFirewallSubnet` |
| `firewall-mgmt` | no | no | — | — | `AzureFirewallManagementSubnet` |

## Role switching contract (`var.role`)

| `var.role` | bastion | firewall | peering | hub remote state |
|---|---|---|---|---|
| `"hub"` | enabled | enabled | none | not read |
| `"spoke"` | disabled | disabled | both directions to hub | required (`var.hub_state_backend`) |

Switch is enforced by:
- `count = var.role == "hub" ? 1 : 0` on bastion/firewall submodules
- `count = var.role == "spoke" ? 1 : 0` on peering + remote-state data source
- `precondition` blocks (LOG-INV style) — see [check.tf invariants](#invariants)

## Day-one deployments

| Stack | Subscription env | State path | Address space |
|---|---|---|---|
| `(npd, hub, hub)` | `SUBSCRIPTION_ID_NPD_HUB` | `hub/npd/vnet.tfstate` | `10.240.4.0/23` |
| `(npd, sp01, spoke)` | `SUBSCRIPTION_ID_NPD_SP01` | `sp01/npd/vnet.tfstate` | `10.240.2.0/24` |

Subnet CIDRs per spec § Root stack.

## Invariants (enforced in `check.tf`)

| ID | Rule | Source |
|---|---|---|
| VNET-INV-1 | `var.region == "swc"` | FR-204 |
| VNET-INV-2 | `var.environment ∈ {"npd","prd"}` (npd-only at MVP, prd added later) | spec |
| VNET-INV-3 | `var.role ∈ {"hub","spoke"}` | C11 |
| VNET-INV-4 | `var.subscription_id` matches `data.azurerm_client_config.current.subscription_id` | FR-205 |
| VNET-INV-5 | Every role in `var.subnets` exists in `local.role_catalogue` | C12 |
| VNET-INV-6 | When `role=spoke`, `var.hub_state_backend != null` AND all 4 fields populated | C10 |
| VNET-INV-7 | When `role=hub`, `var.hub_state_backend == null` (defence-in-depth) | C11 |
| VNET-INV-8 | Naming engine emits the expected vnet + RG canonical names | snapshot |
| VNET-INV-9 | `length(var.address_space) >= 1` AND every entry parses via `cidrhost(..., 0)` | spec |
| VNET-INV-10 | When `role=hub`, both subnet roles `bastion` AND `firewall` (and `firewall-mgmt`) MUST be present in `var.subnets` | spec |

## Out of scope (MVP)

Per spec § Out of scope, plus:
- `prd-hub` and `prd-sp01` deployments (defer to follow-up)
- Hub→spoke peering managed from the hub stack (we manage both sides from the spoke; see C5)
- Diagnostic settings to log analytics (feature 005)
- Private DNS zone vnet links (feature 005)

## Inputs

Root stack `terraform/vnet/` accepts **11** inputs:

| Name | Source | Required | Constraint |
|---|---|---|---|
| `subscription_id` | env | yes | GUID regex |
| `repo` | env | yes | `<org>/<repo>` |
| `region` | tfvars | yes | must be `"swc"` |
| `tenant` | tfvars | yes | `^(hub\|sp[0-9]{2})$` |
| `environment` | tfvars | yes | `^(npd\|prd)$` |
| `role` | tfvars | yes | `"hub"` or `"spoke"` |
| `address_space` | tfvars | yes | list(string), CIDR each |
| `subnets` | tfvars | yes | map(role → cidr) |
| `extra_nsg_rules` | tfvars | no | map(role → list(rule_object)); default `{}` |
| `hub_state_backend` | tfvars | spoke only | object{rg, sa, container, key} or `null` |
| `usecase` | tfvars | no | default `"shd"` |

## Test plan (TDD)

Wrapper module `modules/network/`:
- `positive_baseline_hub.tftest.hcl`
- `positive_baseline_spoke.tftest.hcl`
- `bastion_required_on_hub.tftest.hcl` (omit bastion role → fail)
- `firewall_required_on_hub.tftest.hcl`
- `unknown_role_rejected.tftest.hcl`
- `address_space_empty_rejected.tftest.hcl`

Root stack `terraform/vnet/`:
- `wrong_region.tftest.hcl`
- `wrong_role.tftest.hcl`
- `subscription_mismatch.tftest.hcl`
- `spoke_missing_hub_backend.tftest.hcl`
- `hub_with_hub_backend_rejected.tftest.hcl`
- `plan_zero_diff_hub.tftest.hcl`
- `plan_zero_diff_spoke.tftest.hcl`
- `plan_snapshot_hub.tftest.hcl`
- `plan_snapshot_spoke.tftest.hcl`

Mock-provider override on `data.terraform_remote_state.hub` for spoke tests
(provides synthetic `vnet_id` and `firewall_private_ip`).

## CI

`.github/workflows/vnet.yml`: triggers on changes under
`modules/network/**`, `terraform/vnet/**`,
`variables/npd/{hub,sp01}/vnet.tfvars.json`, `.github/workflows/vnet.yml`.
Matrix: `[modules/network, terraform/vnet]`. Steps: fmt / init / validate / test.

## Open questions

None — all 13 clarifications resolved in spec.md.

## Amendment plan — FR-209 firewall SKU

Branch: `004-vnet-firewall-sku` (off master). Scope: parameterise the hub
firewall + firewall policy SKU tier. Default behaviour preserved (Standard);
hub/npd opts into `Basic`. No new module dependencies; AVM pins unchanged.

### Files touched

- `modules/network/firewall/variables.tf` — new `firewall_sku_tier` variable
  (string, default `"Standard"`, validation `contains(["Basic","Standard","Premium"], var.firewall_sku_tier)`).
- `modules/network/firewall/main.tf` — wire `var.firewall_sku_tier` into both
  `azurerm_firewall_policy.this.sku` and `module.firewall.firewall_sku_tier`
  (AVM `Azure/avm-res-network-azurefirewall/azurerm`).
- `modules/network/variables.tf` — new wrapper-level `firewall_sku_tier`
  (default `"Standard"`, same validation).
- `modules/network/main.tf` — forward to `module.firewall.firewall_sku_tier`.
- `terraform/vnet/variables.tf` — root-stack `firewall_sku_tier`
  (default `"Standard"`, same validation).
- `terraform/vnet/main.tf` — forward to `module.network.firewall_sku_tier`.
- `variables/hub/npd/vnet.tfvars.json` — set `"firewall_sku_tier": "Basic"`
  (spoke tfvars unchanged; spokes do not own the firewall).
- `modules/network/tests/firewall_sku_basic.tftest.hcl` — plan-only assertion
  that `firewall_sku_tier = "Basic"` propagates to both the policy and the
  firewall resources.
- `modules/network/tests/firewall_sku_invalid.tftest.hcl` — variable validation
  via `expect_failures = [var.firewall_sku_tier]` for an unsupported value
  (e.g. `"Free"`).

### AVM module pins

Unchanged. `Azure/avm-res-network-azurefirewall/azurerm` and
`Azure/avm-res-network-firewallpolicy/azurerm` already expose
`firewall_sku_tier` / `sku` — no version bump required.

### Constitution check

No new exception triggered. FR-209 is a parameterisation of existing
firewall behaviour already covered by the original 004 plan; no new AVM
dep, no new provider, no cross-stack contract change.

### Risks (per spec C14.3)

- Standard → Basic (and Basic → Standard) **forces replacement** of both
  `azurerm_firewall_policy.this` and the AVM firewall module's
  `azurerm_firewall` resource → brief hub data-plane outage during apply.
- Spoke route-table next-hop (`firewall_private_ip` from hub remote state)
  is preserved iff the firewall's private IP re-allocates to the existing
  `10.240.5.4`. This holds because `AzureFirewallSubnet` is emptied by the
  destroy step and the first available address (`.4`, after `.0–.3`
  Azure-reserved) is re-assigned on create. Spokes do **not** need a
  re-apply in the common case — flagged for verification at rollout.
- Basic SKU has reduced feature surface (no DNAT proxy, no TLS inspection,
  no IDPS); current hub policy uses none of these, so functional impact is
  nil for hub/npd.

### Test gate (pre-merge)

In both `modules/network/` and `terraform/vnet/`:

```
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform test
```

All GREEN required before merge. New tests `firewall_sku_basic.tftest.hcl`
and `firewall_sku_invalid.tftest.hcl` must pass; existing 004 tests must
remain GREEN (no regression).

### Rollout gate (per spec C14.5)

Post-merge on master:

1. `cd terraform/vnet && terraform init && terraform plan -var-file=../../variables/hub/npd/vnet.tfvars.json -out=hub.npd.tfplan`
2. Inspect plan: confirm whether firewall + policy are `~ update in-place`
   or `-/+ replace`. If replace, schedule a maintenance window, accept the
   brief outage, then `terraform apply hub.npd.tfplan`.
3. Post-apply: re-read hub remote state, confirm `firewall_private_ip ==
   10.240.5.4`; if changed, trigger a spoke re-apply to refresh route tables.
4. Spoke stacks (`sp01/npd`) require no change for this amendment.

### Out of scope

- Spoke-level firewall SKU (spokes do not own a firewall).
- Per-environment defaults beyond hub/npd (prd opt-in deferred).
- Policy rule-collection changes — pure SKU parameterisation only.

## Amendment plan — FR-210 hub default route

**Branch**: `004-vnet-egress` (off master) — PR #8 open
**Spec anchors**: FR-210, C15.1–C15.11 in [spec.md](spec.md)
**Tasks**: Phase 7 (T070–T079) in [tasks.md](tasks.md#phase-7--amendment-hub-default-route-fr-210)

### Scope & rationale

Feature 005 build VM (`vm-bld-shd-hub-npd-swc-001`) failed cloud-init at the
apt step: its subnet `snet-bld-*` has `defaultOutboundAccess=false` and is
bound to the shared hub route table, which contained **zero** routes — so
packets to `azure.archive.ubuntu.com`, `aka.ms`,
`packages.microsoft.com`, and `github.com` had no next-hop and timed out
(C15.1). The Azure CLI install and the GitHub Actions runner download both
hung. Root cause is owned by feature 004's hub network because the same
route table is shared across all hub workload roles (`development`,
`pre-production`, `buildsvr`, `function-app`, `logic-app`), so the fix
must land in the wrapper module, not the buildsvr stack.

Fix: when `var.role == "hub"`, emit a single inline UDR
`udr-defaultroute` 0.0.0.0/0 → `module.firewall[0].private_ip` in the
shared hub route table. Gated by new boolean `enable_hub_default_route`
(default `true` per C15.2 — every hub deployment today already needs
egress, and Azure's `defaultOutboundAccess` deprecation makes the
unrouted hub increasingly unusable). Opt-out (`false`) preserves the
prior empty-routes behaviour exactly (C15.9).

### Files touched (shipped on `004-vnet-egress`)

- [modules/network/main.tf](../../modules/network/main.tf) — added hub
  branch to the `routes = …` ternary inside `module "rt"`; spoke branch
  unchanged (still consumes `var.hub_firewall_private_ip` per C9 / C15.5).
- [modules/network/variables.tf](../../modules/network/variables.tf) —
  new `variable "enable_hub_default_route"` (bool, default `true`,
  hub-only docstring). No `validation` block needed (type system rejects
  non-bool — C15.8).
- [modules/network/tests/hub_default_route.tftest.hcl](../../modules/network/tests/hub_default_route.tftest.hcl)
  — two mocked plan runs: `enabled_by_default` (exercises `default = true`
  path) and `disabled_opt_out` (`enable_hub_default_route = false`). Both
  assert plan success and that the route-table name remains the engine
  canonical `rt-net-shd-hub-npd-swc-001` (C15.10).
- [terraform/vnet/variables.tf](../../terraform/vnet/variables.tf) +
  [terraform/vnet/main.tf](../../terraform/vnet/main.tf) — root-level
  forward of the new variable into `module.network`. No wrapper-level
  validation needed (boolean type, per C15.8). No third boundary.
- No tfvars file change. `variables/hub/npd/vnet.tfvars.json` is *not*
  updated: the `default = true` already turns the route on, so leaving
  the file silent preserves the principle "defaults preserve existing
  behaviour" for any deployment that wants the opt-out.

### Constitution gate review

| Gate | Result | Notes |
|---|---|---|
| I. Subscription pin | PASS | No change to `check.subscription_pinned` — amendment touches routes only. |
| II. Naming engine | PASS | No engine catalogue change. The single inline route uses the literal `udr-defaultroute` per C15.11 (route names are records inside a resource, not catalogued resources). |
| III. Defence-in-depth validation | PASS | Type system handles `bool` — explicit `validation` blocks not required (C15.8); matches existing `firewall_zones` and `firewall_sku_tier`-on-spoke no-op pattern. |
| IV. Tests for every code path | PASS | New file `hub_default_route.tftest.hcl` covers both positive (enabled) and negative-equivalent (opt-out) branches under mocked providers; existing 23 tests remain GREEN (11 module + 12 root, +1 new module test = 24). |
| V. Runtime configurable | PASS | New `enable_hub_default_route` wired through both input boundaries; no hard-coded behaviour. |
| VII. State path | PASS | Backend coordinates unchanged. |
| IX. AVM pins | PASS | No AVM module added or version-bumped; the route is emitted via the existing `Azure/avm-res-network-routetable/azurerm ~> 0.3` `routes` argument already in use. |
| X. `terraform fmt` + `terraform test` | PASS pre-merge | Both modules formatted clean; 24 tests GREEN locally (T074–T075 gate). |

### Documentation deltas

- **`research.md`** — no update. The decision to default to `true` is
  fully captured in C15.2; no new research artefact warranted (no novel
  technology evaluation, no alternative AVM module considered).
- **`data-model.md`** — no update. No new entity or relationship; the
  `routes` map on the existing route-table resource gains one entry that
  varies by `var.role` and `var.enable_hub_default_route`. The wrapper's
  output contract (C13) is unchanged.
- **`quickstart.md`** — no update required. The default is on, so the
  documented quickstart path (`terraform apply` against
  `variables/hub/npd/vnet.tfvars.json`) now produces a hub with working
  egress without any tfvars edit. Operators wanting the opt-out can
  consult the variable docstring in `modules/network/variables.tf` and
  the C15.9 idempotency note in `spec.md` — sufficient at amendment scale.

### Rollout sequencing

Operational steps live in [tasks.md Phase 7](tasks.md#phase-7--amendment-hub-default-route-fr-210):

1. **Pre-merge** (T074–T075): `terraform fmt -recursive` + `terraform test`
   GREEN in both `modules/network/` and `terraform/vnet/`. Already
   satisfied locally on branch `004-vnet-egress` (24 tests passing).
2. **Merge** (T076): squash-merge PR #8 to master, delete branch.
3. **Live apply to hub/npd** (T077): open state SA firewall, `terraform
   init -reconfigure` + `plan` against `variables/hub/npd/vnet.tfvars.json`,
   confirm the plan shows a single in-place add of `udr-defaultroute`
   0.0.0.0/0 → 10.240.5.4 on
   `module.network.module.rt.azurerm_route_table.this` (no other resource
   churn), `apply`, restore state SA firewall.
4. **Validate via build VM re-bootstrap** (T078): `az vm run-command
   invoke` against `vm-bld-shd-hub-npd-swc-001` to re-run
   `/opt/buildsvr/bootstrap.sh`; acceptance is `az --version` returning a
   banner and `/var/log/buildsvr-bootstrap.log` showing the GitHub runner
   archive downloaded + extracted.
5. **Report** (T079): SKU/route change, plan summary, `az --version`
   output back to operator.

### Out of scope (amendment)

- FQDN-based firewall application rule collections (still deferred per
  feature 004 out-of-scope list; Basic SKU's network-rule
  `* → TCP/80,443` is sufficient to unblock cloud-init per C15.6).
- Spoke route tables — unchanged (C15.5; spokes continue to source the
  next-hop from `terraform_remote_state` per C9).
- Per-subnet route-table overrides — the shared hub RT design is
  preserved; per-role override is a separate feature.

## Amendment Plan: Hub & Spoke Vnet Links to Private DNS Zones (FR-211..FR-222)

**Branch**: `004-vnet-dns-links` (off master)
**Spec anchors**: FR-211..FR-222, C16.1..C16.12 in [spec.md](spec.md)
**Tasks**: deferred to the next phase (`/speckit.tasks`); this section
plans only.

### 1. Architecture Decision Record — link resource locus

**Decision**: introduce a new thin wrapper submodule
[`modules/dnslinks/`](../../modules/dnslinks/) that consumes
`vnet_id`, `vnet_name`, `zone_ids` (map of `catalogue_key|fqdn ⇒ zone
resource id`) and emits exactly one
`azurerm_private_dns_zone_virtual_network_link` per zone via
`for_each = var.zone_ids`. The DNS remote-state lookup itself stays at
the root-stack layer (`terraform/vnet/`); the submodule is pure
input-only and has no `terraform_remote_state` coupling.

**Rejected alternative A — inline in `terraform/vnet/main.tf`**: would
work for v1 but forces every future stack that needs vnet links (AKS
private cluster, AML private workspace, future per-app private-link
stacks) to copy the `for_each` block. Violates the DRY principle the
naming/dnszones/network wrappers already establish.

**Rejected alternative B — inside `modules/network/`**: would couple
the reusable network module to DNS remote-state semantics. The network
module is correctly stack-agnostic today (it takes a `hub_vnet_id`
input rather than reaching into hub state); pulling DNS state into it
would regress that separation. The vnet-link concern is a
stack-composition concern, not a network-module concern.

**Decision rationale per C16.9**: matches the "PREFERRED — propose
`modules/dnslinks/`" answer captured in the spec.

### 2. AVM vs bare resource decision

**Finding** (from
https://registry.terraform.io/modules/Azure/avm-res-network-privatednszone/azurerm/latest):

- The AVM module `Azure/avm-res-network-privatednszone/azurerm ~> 0.5`
  exposes `virtual_network_links` as an **input on the parent zone
  module** — i.e. it expects you to be creating the zone in the same
  module call. That path is unusable from the vnet stack because the
  zones are owned by `terraform/dns/` (feature 002) and we MUST NOT
  re-declare them.
- The parent module internally calls a local submodule at
  `./modules/private_dns_virtual_network_link`. That submodule **is**
  registry-published under
  `Azure/avm-res-network-privatednszone/azurerm//modules/private_dns_virtual_network_link`
  and CAN be sourced externally with the parent zone's `resource_id`.

**Decision**: **fall back to the bare
`azurerm_private_dns_zone_virtual_network_link` resource** in
`modules/dnslinks/main.tf`. Justification:

1. **Telemetry blast radius**: the AVM submodule pulls in `modtm` +
   `random_uuid` + `azapi_client_config` per call. With ~25 catalogue
   zones × 2 vnets (hub + sp01) growing to N spokes, that's 50→N×25
   telemetry resources versus zero. The bare resource path is
   substantially leaner with no behavioural difference.
2. **Constitution IX fallback clause**: principle IX (AVM-first)
   explicitly permits the bare resource where the AVM module does not
   expose a consumable submodule for the *cross-stack* shape we need.
   The parent-module path doesn't fit our topology; the published
   sub-submodule fits but adds telemetry weight without functional
   value. This matches the same fallback rationale already accepted
   for `modules/network/peering/` (bare `azurerm_virtual_network_peering`
   under a provider alias).
3. **Drift surface**: a bare resource has a tiny, stable schema
   (`name`, `resource_group_name`, `private_dns_zone_name`,
   `virtual_network_id`, `registration_enabled`, `tags`). The AVM
   submodule wraps the same surface but adds module-version coupling.

**Documentation requirement**: `modules/dnslinks/README.md` MUST open
with a "Why bare resource (Constitution IX fallback)" section
referencing this plan section and FR-220 / C16.10.

### 3. Provider / subscription handling

- vnet-link resources are child resources of the private DNS zone, so
  they MUST be created in the **DNS subscription** that owns the
  parent zones.
- For v1 the DNS subscription and the vnet subscription are both
  `883c9081-23ed-4674-95c5-45c74834e093` (npd-hub == prd-hub for
  shared services; DNS state key is `hub/prd/dns.tfstate` per
  [terraform/dns/backend.tf](../../terraform/dns/backend.tf#L7)), so
  the default `azurerm` provider on the vnet stack already targets the
  correct subscription. No alias is required at the resource level
  today.
- **Multi-sub readiness (FR-214 / C16.4)**: `modules/dnslinks/`
  declares a `providers` block accepting an OPTIONAL aliased provider
  `azurerm.dns`, passed by the root stack. In v1 the root stack passes
  `azurerm.dns = azurerm` (the default). When zones move to a separate
  subscription, the root stack swaps in a properly aliased
  `azurerm.dns` provider configured from
  `var.dns_state_backend.subscription_id` — zero submodule change. The
  same pattern is already in use by `modules/network/peering/`
  (`azurerm.hub` alias), so this is consistent with the codebase.
- The submodule's `variables.tf` MUST also expose an optional
  `dns_subscription_id` string (default `null`) used only for
  documentation / `precondition` invariants, NOT for provider
  configuration (providers cannot be configured from variables).

### 4. Tfvars schema delta

Each consuming tfvars file gains a new top-level `dns_state_backend`
object mirroring the existing `hub_state_backend` shape used by spokes
and the `log_state_backend` shape used elsewhere. JSON form:

```json
{
  "dns_state_backend": {
    "subscription_id":      "883c9081-23ed-4674-95c5-45c74834e093",
    "resource_group_name":  "rg-tfstate-shd-hub-prd-swc-001",
    "storage_account_name": "sttfstateshdhubprdswc001",
    "container_name":       "tfstate",
    "key":                  "hub/prd/dns.tfstate"
  }
}
```

Files to add the block to (additive, no other keys touched):

- [variables/hub/npd/vnet.tfvars.json](../../variables/hub/npd/vnet.tfvars.json)
- [variables/sp01/npd/vnet.tfvars.json](../../variables/sp01/npd/vnet.tfvars.json)
  (when sp01 ships)

Root stack `terraform/vnet/variables.tf` declares
`variable "dns_state_backend"` as an object with the five fields above
(all `string`, none `optional`). A `validation` block asserts the
`key` ends with `.tfstate` (defence-in-depth, mirrors the existing
`hub_state_backend` validation).

### 5. Remote-state lookup location

**Recommendation**: new file
[`terraform/vnet/dns.tf`](../../terraform/vnet/dns.tf) (to be created)
holding:

- `data "terraform_remote_state" "dns"` (unconditional — both hub and
  spoke roles need links per C16.1, so no `count`)
- `module "dnslinks"` call wiring `vnet_id` = `module.network.vnet_id`,
  `vnet_name` = `module.network.vnet_name`,
  `zone_ids` = `data.terraform_remote_state.dns.outputs.zone_ids`

Rationale for a dedicated file rather than appending to `main.tf`:
keeps the DNS-cross-stack concern visually isolated (same pattern as
the existing per-concern files `backend.tf`, `providers.tf`,
`locals.tf`) and makes grep-based reasoning easier when feature 005
diagnostic settings later add a parallel `log.tf`.

The existing hub remote-state block in `main.tf` (count-gated on
`var.role == "spoke"`) stays where it is — it's spoke-only and
intimately tied to the spoke `module.peering` call.

### 6. Backwards compatibility plan

The amendment is **strictly additive**:

- No `moved` blocks (no resources are being renamed or relocated).
- No `replace_triggered_by`, no `lifecycle.replace_triggered_by`.
- No edits to existing vnet / subnet / NSG / route-table / firewall /
  bastion / peering resources.
- New surface added to the plan:
  1. `data.terraform_remote_state.dns` (data source — counts as
     read-only, but Terraform lists it under "Plan: ... to read" not
     "to add"; no infrastructure change).
  2. `module.dnslinks.azurerm_private_dns_zone_virtual_network_link.this["<key>"]`
     × N, where N == number of zones in
     `terraform_remote_state.dns.outputs.zone_ids` (catalogue + custom,
     after `disable_catalogue_zones` filtering by the DNS stack).

**Expected hub plan summary post-amendment** (per FR-222 / C16.12):
`Plan: N to add, 0 to change, 0 to destroy.` where N is the live zone
count from the DNS stack. The pre-apply gate at rollout step 3 below
inspects the plan and aborts if any non-add line appears for any
pre-existing resource.

### 7. Test plan (per FR-218 / C16.8)

All tests use mocked providers + a mocked
`data.terraform_remote_state.dns` (synthesised `zone_ids` map) — the
same mock-overrides pattern already used by the spoke tests in
[terraform/vnet/tests/_fixtures.tftest.hcl](../../terraform/vnet/tests/_fixtures.tftest.hcl).

**New test files in `modules/dnslinks/tests/`** (submodule-level —
covers C16.8 a/b/c against the pure submodule, no remote-state needed):

- `links_count_matches_zones.tftest.hcl` — pass 3 synthetic zone IDs,
  assert `length(azurerm_private_dns_zone_virtual_network_link.this) == 3`.
  (C16.8 a)
- `registration_disabled.tftest.hcl` — assert
  `registration_enabled == false` on every link. (C16.8 b)
- `link_naming.tftest.hcl` — assert each link's `name` ==
  `"vnetlink-${var.vnet_name}"`. (C16.8 c)
- `empty_zones_no_links.tftest.hcl` — pass `zone_ids = {}`, assert
  zero `this` resources, plan succeeds. (C16.8 d)

**New test file in `terraform/vnet/tests/`** (integration — covers
the remote-state wiring at the root layer):

- `dnslinks_remote_state_wiring.tftest.hcl` — mocks
  `data.terraform_remote_state.dns` with a 2-zone `zone_ids` output;
  asserts the `module.dnslinks` instance receives the mocked map and
  plans 2 link resources; runs in both `role=hub` and `role=spoke`
  variants in two `run` blocks.

**Existing test files to extend** (additive `expect_failures` /
post-condition assertions — no rewrite):

- [terraform/vnet/tests/plan_zero_diff_hub.tftest.hcl](../../terraform/vnet/tests/plan_zero_diff_hub.tftest.hcl)
  and [plan_zero_diff_spoke.tftest.hcl](../../terraform/vnet/tests/plan_zero_diff_spoke.tftest.hcl)
  — wire the mocked DNS remote-state into the existing fixture so the
  zero-diff property continues to hold WITH the new module call in the
  graph (C16.7 idempotency proof at the stack level).
- [terraform/vnet/tests/_fixtures.tftest.hcl](../../terraform/vnet/tests/_fixtures.tftest.hcl)
  — add a reusable `dns_state_override` shape and a default mock
  payload (`zone_ids = { "blob" = "/subscriptions/.../privateDnsZones/privatelink.blob.core.windows.net" }`)
  so every existing test inherits a working DNS mock without per-file
  duplication.

**Test count delta**: +4 new files in `modules/dnslinks/tests/`,
+1 new file in `terraform/vnet/tests/`, plus extensions to 3 existing
fixtures. Total new tests ≥ 5, satisfying FR-218's "at minimum four"
floor with margin.

### 8. Rollout sequence

1. **Implement code + tests** on branch `004-vnet-dns-links`:
   - create `modules/dnslinks/{main.tf,variables.tf,outputs.tf,versions.tf,providers.tf,README.md,check.tf}`
   - create `modules/dnslinks/tests/*.tftest.hcl` (4 files)
   - create `terraform/vnet/dns.tf` + new variable in
     `terraform/vnet/variables.tf`
   - extend `terraform/vnet/tests/` (1 new + 3 extended)
   - add `dns_state_backend` block to
     `variables/hub/npd/vnet.tfvars.json` (and `variables/sp01/npd/`
     once spoke ships)
   - run `terraform fmt -recursive` + `terraform test` in
     `modules/dnslinks/`, `terraform/vnet/` — all GREEN before push.
2. **PR + squash-merge** to master, delete remote + local branch.
3. **Live apply to hub/npd** (operator workstation):
   - temp-open state SA firewall (add operator public IP, set
     `defaultAction=Allow` or add the IP rule)
   - `cd terraform/vnet && terraform init -reconfigure`
   - `terraform plan -var-file=../../variables/hub/npd/vnet.tfvars.json -out=hub.npd.tfplan`
   - **GATE per C16.12**: inspect the plan summary. MUST be
     `Plan: N to add, 0 to change, 0 to destroy.` where every "add"
     line is either `data.terraform_remote_state.dns` or
     `module.dnslinks.azurerm_private_dns_zone_virtual_network_link.this[...]`.
     ABORT if any other change line appears.
   - `terraform apply hub.npd.tfplan`
   - restore state SA firewall (`publicNetworkAccess=Disabled`,
     `defaultAction=Deny`, remove temp IP rule) per CLAUDE.md.
4. **Live verification** from build VM
   `vm-bld-shd-hub-npd-swc-001`:
   - `az vm run-command invoke -g <rg> -n vm-bld-shd-hub-npd-swc-001 --command-id RunShellScript --scripts "dig +short privatelink.blob.core.windows.net SOA"`
   - Acceptance: the SOA query returns the Azure-internal Private DNS
     SOA (`azureprivatedns.net`-anchored authority), proving the vnet
     resolver now consults the linked private zone rather than public
     DNS. A non-existent A record (NXDOMAIN) is fine and expected;
     authority-from-private-zone is the contract we are testing.
   - Optional secondary check:
     `dig +short privatelink.vaultcore.azure.net SOA` → same shape.
5. **Deferred — sp01/npd**: when sp01 first applies (separate
   workflow), it inherits the same code path. The sp01 tfvars file
   gains the same `dns_state_backend` block at that point. No
   additional code change.

### 9. Open risks

- **Zone count growth**: the DNS catalogue currently holds ~25 zones
  (per
  [modules/dnszones/catalogue.tf](../../modules/dnszones/catalogue.tf)).
  Every catalogue addition multiplies into N link resources per vnet
  per apply. At 25 zones × 1 hub vnet = 25 links today; at 25 zones ×
  5 spokes future = 125. Still well within Azure limits (1000 links
  per zone, 1000 zones per subscription) but the per-vnet plan-time
  cost grows linearly. **Mitigation**: flag for review when the
  catalogue exceeds 50 zones; consider tag-based opt-out at that
  point (would require a new spec amendment introducing per-zone
  metadata).
- **DNS state file coupling**: this stack now depends on
  `hub/prd/dns.tfstate` continuing to exist with output keys
  `zone_ids` / `zone_names`. If feature 002's DNS stack is ever
  renamed, relocated (e.g. moved to a `services/dns/` path), or has
  its output contract changed, the vnet stack breaks on the next
  init/plan. **Mitigation**: (a) the DNS stack's output contract
  is locked in `specs/002-private-dns-zones/contracts/`; (b) any
  future move/rename of the DNS state key MUST include a coordinated
  PR that updates every `dns_state_backend.key` in all consuming
  tfvars files in the same commit, and re-runs `terraform init
  -reconfigure` on every consumer stack. Document this in the DNS
  stack's README as part of T-followup.
- **`registration_enabled = false` is correct for private-link
  zones**: enabling it on a `privatelink.*` zone would auto-register
  VM hostnames into the wrong namespace and cause subtle resolution
  bugs. The submodule MUST hard-code `false` (no caller override) to
  prevent foot-guns. This is captured by FR-212 / C16.2 — design the
  module to NOT expose `registration_enabled` as an input at all.


---

## Amendment 2 Plan — Drift Reconciliation (FR-223..FR-225)

### §10. Scope

Two surgical config fixes plus one bastion-PIP refactor inside the
network wrapper module, executed under the existing constitution and
without changing the public interface of `modules/network/`,
`modules/network/bastion/`, or `modules/network/firewall/`. Root
stack `terraform/vnet/` is untouched. Tfvars are unchanged. No new
modules are introduced.

### §11. Approach per FR

#### FR-223 — Hard-coded `ip_tags` on first-party PIPs

Add `ip_tags = { FirstPartyUsage = "/Unprivileged" }` inside both
`module "pip_data"` and `module "pip_mgmt"` calls in
`modules/network/firewall/main.tf`, and inside the new bastion PIP
module call introduced under FR-224. The value is a hard-coded local
constant (not a variable) — see C16.14 and per Constitution III
(defaults preserve behaviour, but here the *Azure* default differs
from our config default; this amendment aligns the two).

#### FR-224 — Bastion BYO PIP refactor

Replace the bastion AVM's embedded PIP with an external one:

```hcl
# modules/network/bastion/main.tf (after refactor)

module "pip" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "~> 0.2"

  name                = var.public_ip_name
  location            = var.location
  resource_group_name = split("/", var.resource_group_id)[4]
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  ip_tags             = { FirstPartyUsage = "/Unprivileged" }
  tags                = var.public_ip_tags
  enable_telemetry    = false
}

module "bastion" {
  source  = "Azure/avm-res-network-bastionhost/azurerm"
  # ...unchanged...
  ip_configuration = {
    name                 = "ipconfig"
    subnet_id            = var.subnet_id
    create_public_ip     = false
    public_ip_address_id = module.pip.public_ip_id
  }
}
```

Bastion submodule public interface gains one optional input
(`public_ip_tags`, default `{}`) and one new output
(`public_ip_id`); existing inputs (`name`, `location`,
`resource_group_id`, `subnet_id`, `public_ip_name`, `tags`) and
existing outputs (`resource_id`, `name`) are preserved unchanged.

`modules/network/main.tf` line 132 (the existing
`module "bastion"` block in the wrapper) gains a single new line
`public_ip_tags = module.naming.names[local.pip_canonical_names.bas].tags`
so the new PIP carries the same engine-derived tags the embedded one
did.

#### FR-225 — Per-service serviceEndpoint locations

Introduce in `modules/network/locals.tf`:

```hcl
storage_se_locations = {
  swedencentral = ["swedencentral", "swedensouth"]
}
```

and rewrite the inline expression in `modules/network/main.tf`:

```hcl
service_endpoints_with_location = [
  for ep in local.role_catalogue[r].service_endpoints : {
    service   = ep
    locations = ep == "Microsoft.Storage"
                ? lookup(local.storage_se_locations, local.region_full, ["*"])
                : ["*"]
  }
]
```

The `lookup(..., ["*"])` fallback preserves today's behaviour for
unmapped regions (C16.16). The `region_full` local already exists in
`modules/network/locals.tf` (resolved via the naming engine).

### §12. State migration (C16.18)

Because FR-224 changes the address of the bastion PIP from
`module.network.module.bastion[0].module.bastion.module.public_ip_address[0].azurerm_public_ip.this`
to
`module.network.module.bastion[0].module.pip.azurerm_public_ip.this`,
Phase 9 MUST run a `terraform state mv` BEFORE the gate plan. The
move is performed against the live `hub/npd/vnet.tfstate` backend
while the SA firewall is temporarily open (Phase 9 T119).

If the state mv is skipped, the plan will show one destroy + one add
for the bastion PIP, failing the FR-222 gate.

### §13. Testing strategy

Reuse existing mocked root-stack tests (`terraform/vnet/tests/*`)
with additions. All tests run with the existing `mock_provider`
stack (azurerm + azapi + modtm + random + time + dns alias).

- `pip_ip_tags_present.tftest.hcl` — single `run` block with
  `command = plan` against hub fixture; uses
  `expect_failures = []` and inspects the plan to assert
  `length([for r in run.<rname>.<resource>... : r if r.ip_tags == { FirstPartyUsage = "/Unprivileged" }]) == 3`.
  Practical implementation: use `assert` with a
  `module.network.module.firewall[0].module.pip_data.azurerm_public_ip.this.ip_tags["FirstPartyUsage"]`
  reference once the resource is created during plan.
- `subnet_storage_endpoint_regional.tftest.hcl` — single `run` block
  with `command = plan` against hub fixture; asserts that the
  `dev` subnet's `service_endpoints_with_location` includes
  `{ service = "Microsoft.Storage", locations = ["swedencentral", "swedensouth"] }`
  and that the same subnet still emits
  `{ service = "Microsoft.KeyVault", locations = ["*"] }`.
- Bastion BYO PIP wiring is implicitly covered by the first test
  (three PIPs ⇒ bastion's external PIP is one of them); no separate
  test required to keep test count proportionate.

Existing tests (`plan_zero_diff_*`, `plan_snapshot_*`) MUST continue
to pass without modification — the public interface is unchanged.

### §14. Rollout (Phase 9)

Hub-only live rollout, mirroring Phase 8 (T111-T118):

1. Open state SA firewall to operator IP (T119).
2. `terraform init -reconfigure -backend-config=.../backend.hcl -backend-config="key=hub/npd/vnet.tfstate"`.
3. **State move** for bastion PIP (T121, MANDATORY per C16.18).
4. `terraform plan -out hub.npd.tfplan`.
5. **GATE per FR-222**: plan summary MUST be `Plan: 0 to add, 0 to change, 0 to destroy.`. ABORT and revert state mv otherwise.
6. (no apply — gate alone proves zero-diff convergence; if T123 GATE passes, code has converged with reality)
7. Restore SA firewall lock.
8. Report and mark Phase 9 complete.

> No `terraform apply` in Phase 9 — the entire purpose of this
> amendment is to make the *plan* a no-op against live Azure. If the
> gate is satisfied, no resources need touching.

---

## Amendment 2026-06-02 — FR-226 dedicated Foundry agent subnet role (engine)

**Scope.** Add one `agents` role to the module-internal subnet role catalogue
(`modules/network/locals.tf`), delegated `Microsoft.App/environments`,
`abbr3 = "agt"`, `needs_nsg = true`, `needs_route_table = false`,
`service_endpoints = []`. Purely additive; no existing role/default changes;
no naming-engine (001) change (subnet purposes are free-form abbr3); the
existing `VNET-INV-5` precondition auto-validates the new role.

**Files touched.**
- `modules/network/locals.tf` — new `agents` entry in `local.role_catalogue`.
- `modules/network/variables.tf` — `agents` added to the static VNET-INV-5
  `var.subnets` key allow-list.
- `modules/network/outputs.tf` — test-support introspection outputs
  `subnet_delegations` + `subnet_route_table_attached` (mirrors the existing
  `subnet_service_endpoints` plan-test output).
- `modules/network/tests/agents_role_delegation.tftest.hcl` — new test.

**Verification (plan-level only, mocked, `-backend=false`).**
- `terraform fmt -recursive` clean.
- `terraform -chdir=modules/network test` → 100% pass (existing +
  `agents_role_delegation`).

**Rollout.** None — engine-only, no instance selects `agents` yet. Lighting it
up is the `102-sp01-npd-vnet` address-space expansion (CA-013 #4). Merge-only PR.
