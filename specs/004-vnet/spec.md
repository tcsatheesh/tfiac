# Feature 004 — Hub & Spoke Network Foundation (generic engine)

**Status**: Implemented on master alongside spec.

> **ENGINE FEATURE — instances live in their own features (2026-06-01 retro-split).**
> This feature owns the **generic, reusable** network engine (`modules/network/`)
> and the generic root stack `terraform/vnet/` ONLY. It defines *how* a hub or
> spoke vnet is built (role catalogue, NSGs, route tables, peering, bastion,
> firewall) but deploys **nothing** by itself. Every concrete deployment —
> its CIDRs, subnet map, `firewall_sku_tier`, backend state key, CI path, and
> rollout command — lives in a dedicated **instance feature** that pins one
> `variables/<tenant>/<env>/vnet.tfvars.json` file:
>
> | Instance feature | Tenant/env | Role | tfvars |
> |---|---|---|---|
> | [101-hub-npd-vnet](../101-hub-npd-vnet/spec.md) | hub/npd | hub | `variables/hub/npd/vnet.tfvars.json` |
> | [102-sp01-npd-vnet](../102-sp01-npd-vnet/spec.md) | sp01/npd | spoke | `variables/sp01/npd/vnet.tfvars.json` |
>
> **Adding a new spoke vnet is a new instance feature, not a change here.**
> See the "Add another spoke" runbook in
> [102-sp01-npd-vnet](../102-sp01-npd-vnet/spec.md). Touch this feature only
> when the *engine* itself changes (new subnet role, new toggle, peering
> behaviour, etc.). The day-one CIDRs recorded below are retained for history;
> they are now owned by the instance features above.

## Summary

Replaces the legacy `modules/vnet/` (with its co-located `bastion/`,
`firewall/`, `nsgrules/` sub-folders) and the per-stack ad-hoc layouts
with a clean **engine-driven network module** that supports:

| Concern | Behaviour |
|---|---|
| Virtual network | One vnet per stack with caller-supplied `address_space` |
| Subnets | Intent-driven (role catalogue) — caller passes `{ role => cidr }` |
| NSGs | Auto-attached per subnet role (role catalogue decides) |
| Route tables | One per-vnet `rt-...-001` with a `0.0.0.0/0 → firewall` route; attached to subnets per role |
| Bastion | Optional `enable_bastion=true` (hub-only). Submodule under `modules/network/bastion/`. |
| Firewall | Optional `enable_firewall=true` (hub-only). Submodule under `modules/network/firewall/` — basic policy + data + mgmt PIPs. |
| Peering | Caller-side `vnet_peering` block on the spoke stack consumes the hub vnet ID via `terraform_remote_state`. |
| NSG rules | Per-subnet-role baseline rules where Azure mandates them (Bastion). Caller may append custom rules per subnet role. |

CIDRs are taken from `temp/hub.npd.vnet.yaml` and `temp/sp01.npd.vnet.yaml`
(Q5 — YAML is consulted only for address space facts). Names, tags, RG
layout, and counts are 100% derived from the engine.

## Subnet role catalogue (module-internal)

| Role | Azure-mandated name | Default NSG | Default route table | Default service endpoints | Default delegation |
|---|---|---|---|---|---|
| `development` | (engine-named) | yes | yes | Storage, KeyVault | — |
| `pre-production` | (engine-named) | yes | yes | Storage, KeyVault | — |
| `api-management` | (engine-named) | yes | no | — | — |
| `buildsvr` | (engine-named) | yes | yes | — | — |
| `bastion` | `AzureBastionSubnet` | yes (baseline rules) | no | — | — |
| `firewall` | `AzureFirewallSubnet` | no | no | — | — |
| `firewall-mgmt` | `AzureFirewallManagementSubnet` | no | no | — | — |
| `function-app` | (engine-named) | yes | yes | — | `Microsoft.Web/serverFarms` |
| `logic-app` | (engine-named) | yes | yes | — | `Microsoft.Web/serverFarms` |

(Q8=A — intent-driven roles live inside the module catalogue; the caller
passes role+cidr only.)

## Root stack

A single generic root stack `terraform/vnet/` switches between hub and
spoke behaviour via `var.role`. Per-deployment inputs live in
`variables/<env>/<scope>/vnet.tfvars`. Day-one deployments:

- `(npd, hub, role=hub)` — `variables/npd/hub/vnet.tfvars`
  - address_space `["10.240.4.0/23"]`
  - Subnets: development (10.240.4.0/26), pre-production (10.240.4.64/26),
    api-management (10.240.4.144/28), buildsvr (10.240.4.160/28),
    bastion (10.240.4.192/28), firewall (10.240.5.0/26),
    firewall-mgmt (10.240.5.64/26)
  - Bastion + Firewall enabled (auto when `role = hub`)
- `(npd, sp01, role=spoke)` — `variables/npd/sp01/vnet.tfvars`
  - address_space `["10.240.2.0/24"]`
  - Subnets: development (10.240.2.0/26), pre-production (10.240.2.64/26),
    logic-app (10.240.2.128/28), function-app (10.240.2.144/28),
    preprod-logic (10.240.2.160/28), preprod-func (10.240.2.176/28)
  - Peers to the hub via `terraform_remote_state` (configured by
    `var.hub_state_backend`)
  - Routes default route through the hub firewall private IP (read from
    the same remote state)

## Requirements

- **FR-201**: Engine produces every name (vnet, subnet (where Azure permits),
  nsg, route_table, bastion, firewall, public_ip).
- **FR-202**: Subnet roles `bastion`, `firewall`, `firewall-mgmt` use
  Azure-mandated literal names; the engine entry for the snet record is
  still created so tagging stays consistent.
- **FR-203**: Six-key baseline tags on every resource.
- **FR-204**: Region allowlist `["swedencentral"]` per stack.
- **FR-205**: `check.subscription_pinned` on every root stack.
- **FR-206**: Spoke→hub peering uses `terraform_remote_state` against
  the hub vnet stack's state in Azure Storage. The spoke supplies the
  hub backend coordinates via `var.hub_state_backend`.
- **FR-207**: Caller may extend per-subnet-role NSG rules through
  `var.extra_nsg_rules = { role => [ rule_object ] }`.
- **FR-209**: Hub firewall SKU tier is a per-deployment input
  `var.firewall_sku_tier ∈ { "Basic", "Standard", "Premium" }`,
  default `"Standard"`. The associated `azurerm_firewall_policy.sku`
  follows the same tier value. Spoke role ignores this variable.
- **FR-210**: Hub workload subnets default to routing
  `0.0.0.0/0 → module.firewall[0].private_ip` via the shared hub route
  table, so subnets with `defaultOutboundAccess=false` (e.g. `buildsvr`)
  can reach the internet through the in-vnet firewall. Toggle:
  `var.enable_hub_default_route` (bool, default `true`). `AzureFirewallSubnet`
  and `AzureFirewallManagementSubnet` do not attach the shared route table
  (`needs_route_table = false`) so there is no routing loop. Spoke role
  ignores this variable (spoke continues to source the next-hop IP via
  `var.hub_firewall_private_ip` from remote state per C9).
- **FR-208**: Legacy `modules/vnet/` is parked under `modules/vnet/` (no
  longer consumed; previous root stacks moved to `terraform/_legacy/`).
  No `moved.tf` — these legacy modules were not consumed by an active
  root stack.

## Out of scope (deferred — explicitly recorded)

- Detailed APIM-subnet NSG rule set (legacy `nsgrules/apim.tf` is gone;
  a follow-up will reintroduce hardened rules under
  `var.extra_nsg_rules["api-management"]`).
- Firewall **rule collections** (legacy `firewall/rulecollections.tf` and
  `firewall/rulecollection/`). The firewall is provisioned with an empty
  policy; rules land in a follow-up.
- Diagnostic settings to the prd Log Analytics workspace — added under
  feature 005 (DNS + vnet diagnostics).
- VPN gateway, ExpressRoute gateway, AzureFirewall with forced-tunnel.
- Private DNS zone vnet links (these belong to the DNS stack and will be
  added as a feature 005 enhancement once vnets exist).

## Test plan

For each deployment of the generic stack `terraform/vnet/` (`npd/hub`,
`npd/sp01`):
1. `positive_baseline.tftest.hcl` — `terraform plan` succeeds; asserts
   `output.vnet_name == "vnet-<tenant>-<env>-sdc-001"`.
2. `negative_subscription_mismatch.tftest.hcl` — `expect_failures = [check.subscription_pinned]`.
3. `negative_disallowed_region.tftest.hcl` — `expect_failures = [var.region]`.

## Clarifications

Resolved autonomously per established precedents from features 002/003.

- **C1 — region abbr**: use `swc` (not `sdc` in test plan). Aligns with feature 003 and the canonical Sweden Central short code already used by `terraform/log/`.
- **C2 — AVM module pins** (Constitution IX):
  - `Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`
  - `Azure/avm-res-network-virtualnetwork/azurerm ~> 0.8` (creates the vnet, subnets, and intra-stack peerings)
  - `Azure/avm-res-network-networksecuritygroup/azurerm ~> 0.4`
  - `Azure/avm-res-network-routetable/azurerm ~> 0.3`
  - `Azure/avm-res-network-bastionhost/azurerm ~> 0.4`
  - `Azure/avm-res-network-azurefirewall/azurerm ~> 0.4`
  - `Azure/avm-res-network-publicipaddress/azurerm ~> 0.2`
- **C3 — state path** (Constitution VII): `<scope>/<env>/vnet.tfstate` injected at `terraform init` via `-backend-config="key=…"`. Day-one: `hub/npd/vnet.tfstate`, `sp01/npd/vnet.tfstate`.
- **C4 — spec status**: the original "Implemented on master alongside spec" line was aspirational; corrected — feature is implemented on branch `004-vnet`.
- **C5 — peering submodule**: spoke stack creates BOTH peering sides via a dedicated `modules/network/peering/` submodule that uses two provider aliases (`azurerm.this` = spoke, `azurerm.hub` = aliased to the hub subscription). It uses `azurerm_virtual_network_peering` × 2 — a **documented Constitution IX exception** because there is no published standalone AVM peering submodule and the AVM vnet module's `peerings` argument can only manage peerings on its own vnet (so it cannot create the hub-side peering from the spoke stack).
- **C6 — day-one scope**: `npd` only. `prd-hub` and `prd-sp01` deferred to a follow-up feature.
- **C7 — firewall policy**: empty policy whose SKU follows `var.firewall_sku_tier` (default `Standard`; rule collections deferred per spec out-of-scope). Per FR-209 the tier is now an input — initial implementation hard-coded `Standard`; superseded by the firewall-sku amendment. Azure mandates that `azurerm_firewall.sku_tier` and `azurerm_firewall_policy.sku` match exactly, so the module derives both from the single input — no independent policy-SKU knob is exposed.
- **C8 — bastion NSG**: AVM `avm-res-network-bastionhost` defaults; no hand-crafted rules at MVP.
- **C9 — spoke default route**: `0.0.0.0/0 → <hub firewall private IP>` read from the hub stack via `terraform_remote_state`.
- **C10 — hub backend coordinates**: spoke `var.hub_state_backend = { resource_group_name, storage_account_name, container_name, key }`; spoke uses the azurerm backend with `use_azuread_auth = true` (mirrors the dns + log precedent).
- **C11 — role switching**: `var.role ∈ { "hub", "spoke" }`. `hub` → bastion + firewall enabled, peering disabled, no remote state read. `spoke` → bastion + firewall disabled, peering enabled, hub remote state required, RT default route via hub fw private IP.
- **C12 — engine usage**: top-level entries `vnet`, `nsg` (per non-bastion/non-firewall subnet role), `route_table`, plus per-stack `resource_group`; child entries `subnet` (per subnet role, with `child_purpose` ≡ role abbr); `vnet_bastion` and `vnet_firewall` (singletons) on hub only; `public_ip` × 1 (bastion) + × 2 (firewall data + mgmt) on hub. Subnet roles `bastion`, `firewall`, `firewall-mgmt` get their Azure-mandated literal names (`AzureBastionSubnet`, `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`) — the engine still emits the canonical record for tagging coherence (FR-202).
- **C13 — output contract**: `vnet_id`, `vnet_name`, `vnet_address_space`, `subnets` (map of role → `{ id, name, address_prefix }`), `nsgs` (map of role → `{ id, name }`), `route_table_id`, `route_table_name`, `firewall_private_ip` (hub only; `null` on spoke), `firewall_id` (hub only), `bastion_id` (hub only), `resource_group_name`, `resource_group_id`, `naming` (engine `names` map).
- **C14 — firewall SKU amendment (FR-209) resolved details**: autonomous resolutions for the `var.firewall_sku_tier` amendment that were not explicitly specified by the requester.
  - **C14.1 — validation locus**: same `validation { condition = contains(["Basic","Standard","Premium"], var.firewall_sku_tier) }` block is repeated at every input boundary (`modules/network/firewall/variables.tf`, `modules/network/variables.tf`, `terraform/vnet/variables.tf`) for fail-fast defence-in-depth. The firewall submodule remains the authoritative enforcement point; the wrapper and root copies catch invalid values before any data source is read or any mock provider is loaded. Rationale: validation blocks are cheap, the duplication is mechanical and visible, and root-level rejection produces a clearer error than a deeply nested module trace.
  - **C14.2 — zones interaction**: `firewall_sku_tier` does not mutate `firewall_zones`. The two inputs remain orthogonal; if a caller selects `Basic` in a region/configuration where Azure rejects the requested zone set, the error surfaces at apply. Rationale: keeps the SKU variable single-purpose; zone policy is a separate concern already owned by the caller.
  - **C14.3 — migration semantics (Standard ⇄ Basic)**: changing `firewall_sku_tier` on a deployed hub is a **destroy-and-recreate** operation for both `azurerm_firewall.*` and `azurerm_firewall_policy.*` (Azure does not support in-place SKU tier changes between Basic and Standard). Operators MUST inspect `terraform plan` for `# forces replacement` on the firewall + policy resources before `terraform apply`, and accept the resulting short outage on the hub data path. The spoke `0.0.0.0/0` route target (`firewall_private_ip` via remote state) is preserved across the recreate because the firewall is redeployed into the same `AzureFirewallSubnet` with the same static private IP allocation pattern.
  - **C14.4 — policy SKU coupling**: see C7 — the module derives `azurerm_firewall_policy.sku` from the same `var.firewall_sku_tier`. No independent policy SKU input.
  - **C14.5 — post-merge rollout to hub/npd**: out of scope for this spec amendment. The code change ships the variable + default `Standard` (zero behaviour change). Switching `variables/hub/npd/vnet.tfvars.json` to `"firewall_sku_tier": "Basic"` and applying it against the live hub is tracked as a separate operational task and not gated by this spec's test plan.
- **C15 — hub default route amendment (FR-210) resolved details**: autonomous resolutions for the FR-210 amendment.
  - **C15.1 — scope of fix**: Feature 005 build server (`snet-bld-*`) was provisioned with `defaultOutboundAccess=false` and a UDR-bound route table containing zero routes; the apt step of cloud-init timed out connecting to `azure.archive.ubuntu.com`, blocking Azure CLI install and GitHub Actions runner download. Root cause sits in feature 004's hub network: the shared hub route table was never given a `0.0.0.0/0` next-hop. Fix lands in feature 004 because every hub workload subnet (`development`, `pre-production`, `buildsvr`, `function-app`, `logic-app`, etc.) shares the same route table and would benefit equally.
  - **C15.2 — default**: `var.enable_hub_default_route = true`. Rationale: every existing hub workload role already has `needs_route_table = true` in `local.role_catalogue` AND `defaultOutboundAccess=false` semantics across Azure are tightening; emitting the route by default makes the hub usable out of the box. Operators who want full-isolation hubs can flip the variable to `false` per-deployment.
  - **C15.3 — chicken-and-egg**: the hub route table now references `module.firewall[0].private_ip`. Terraform's DAG handles this naturally because `module.rt` and `module.firewall` are independent siblings of `module.vnet`; the AzureFirewallSubnet attaches to the vnet, the firewall consumes that subnet, the firewall publishes its private IP, the route table consumes that IP, and `module.vnet`'s subnet associations attach the route table to non-firewall subnets afterwards. No cycle.
  - **C15.4 — loop avoidance**: `AzureFirewallSubnet` (`firewall` role) and `AzureFirewallManagementSubnet` (`firewall-mgmt` role) carry `needs_route_table = false` in `local.role_catalogue` (locals.tf), so the route table is *not* attached to those subnets — the firewall's own traffic is never sent back through itself. `AzureBastionSubnet` (`bastion` role) is also `needs_route_table = false` per Azure mandate.
  - **C15.5 — spoke contract unchanged**: spoke role continues to source the next-hop via `var.hub_firewall_private_ip` (from remote state per C9). The new variable `enable_hub_default_route` is read only when `role = "hub"`. No spoke tfvars change.
  - **C15.6 — Basic SKU compatibility**: the route 0.0.0.0/0 → fw-private-ip is a network-level UDR; it is independent of the firewall policy SKU. The current hub runs Basic (per FR-209 rollout in T069) with the existing `* → TCP/80,443` network rule collection, which is sufficient for unblocking the buildsvr cloud-init path (apt mirrors, Microsoft packages, github.com, etc.). FQDN-based application rule collections are still deferred per spec out-of-scope ("Firewall rule collections" line).
  - **C15.7 — post-merge rollout**: included in scope for this amendment (unlike C14.5). Phase 7 T070–T079 cover the live apply to hub/npd, the cloud-init re-trigger via `az vm run-command invoke`, and verification that `az --version` returns on `vm-bld-shd-hub-npd-swc-001`.
  - **C15.8 — variable surface & validation locus**: `enable_hub_default_route` is declared at two input boundaries: `modules/network/variables.tf` (engine module) and `terraform/vnet/variables.tf` (root stack). There is no third wrapper. Because the type is `bool`, Terraform's type system rejects non-boolean values at parse time, so no explicit `validation` block is needed (unlike `firewall_sku_tier` in C14.1, which is a free-form string). The variable is consulted only inside `var.role == "hub"` branches; setting it on a spoke deployment is silently ignored (no error) — consistent with `firewall_sku_tier` (C7) and `firewall_zones` (C14.2) which also no-op on spokes.
  - **C15.9 — opt-out semantics & idempotency**: when `enable_hub_default_route = false`, the shared hub route table `rt-net-<usecase>-<tenant>-<env>-<region>-001` is still created (preserves the engine catalogue from C12 and FR-202 naming) but its `routes` map is empty — exactly the pre-amendment behaviour. Flipping the toggle on a deployed hub does not replace the route table resource; only the inline `routes` block churns (add/remove the single `to-firewall` entry). Operators can safely toggle false → true → false; the route table's ID, name, and subnet associations are stable across toggles, so dependent stacks (spoke peerings, NSG rules) are not disturbed.
  - **C15.10 — test coverage**: `modules/network/tests/hub_default_route.tftest.hcl` covers both branches under mocked providers: `hub_default_route_enabled_by_default` (no explicit variable — exercises the `default = true` path) and `hub_default_route_disabled_opt_out` (`enable_hub_default_route = false`). Both runs assert plan success and that the route table name remains the engine canonical (`rt-net-shd-hub-npd-swc-001`). No negative-validation test is required because the variable is `bool` (per C15.8). This satisfies the standing autonomy rule "tests added for every new variable/code path (positive + negative)".
  - **C15.11 — route name literal**: the single entry in the inline `routes` map is named `udr-defaultroute` (literal string, identical on hub and spoke per `modules/network/main.tf`). This is **not** a deviation from FR-202 or C12: the naming engine catalogues *resources* (vnet, route_table, subnet, nsg, firewall, bastion, public_ip), not individual *records inside a resource*. Azure scopes route-name uniqueness per route table, so one literal name is sufficient; sharing the same literal between hub and spoke simplifies grepping/diagnostics and matches how `udr-` is the canonical UDR prefix in the existing operational vocabulary.

## Amendment: Hub & Spoke Vnet Links to Private DNS Zones (FR-211..FR-222)

**Status**: Amendment — appended to in-flight feature 004. Code change
not yet shipped at the time of this spec edit. Per CLAUDE.md amendment
rule, the new requirements append to existing FR-201..FR-210 and
C1..C15 numbering without renumbering them.

### User Story (P1) — Private DNS resolution from inside every vnet

**As an** Azure workload owner deploying a private endpoint into the
hub or any spoke vnet,
**I want** A-record lookups for `*.blob.core.windows.net`,
`*.vaultcore.azure.net`, `*.azurewebsites.net`, etc. issued from inside
the vnet to resolve to the private-link IP,
**so that** my workloads (build server, function apps, jump hosts,
future AKS pods, etc.) actually reach storage / KeyVault / web apps
over the private path instead of falling back to the public endpoint
(or failing outright when public access is disabled at the data plane).

**Gap today**: the 25 Private DNS Zones provisioned by feature 002
(`terraform/dns/`, AVM `avm-res-network-privatednszone ~> 0.5`) live in
the prd-hub DNS RG but no `azurerm_private_dns_zone_virtual_network_link`
ties them to `vnet-net-shd-hub-npd-swc-001` (or to any spoke vnet).
Lookups from inside the vnets therefore go to public DNS, returning
the public IP — defeating the whole private-endpoint model.

### Acceptance Scenarios

1. **Hub vnet link coverage**: after `terraform apply` of
   `terraform/vnet/` with `role=hub`, the plan creates exactly N
   `azurerm_private_dns_zone_virtual_network_link` resources, where N
   equals `length(data.terraform_remote_state.dns.outputs.zone_ids)`
   (currently 25 with default catalogue, fewer when
   `disable_catalogue_zones` is set).
2. **Spoke vnet link coverage**: same assertion holds for
   `role=spoke` — every spoke vnet (sp01 today, future sp02..spNN)
   links to the same N zones, sourcing the zone IDs from the SAME
   `terraform_remote_state.dns` reference.
3. **Idempotent re-apply**: a second `terraform plan` immediately
   after a successful apply shows **zero** changes — no churn on link
   names, no churn on registration_enabled, no churn on the zone-id
   list.
4. **Catalogue shrink → link auto-destroy**: when an operator sets
   `disable_catalogue_zones = ["privatelink.blob.core.windows.net"]`
   in the DNS stack tfvars, re-applies `terraform/dns/`, then
   re-applies `terraform/vnet/`, the vnet plan destroys exactly one
   link (`vnetlink-vnet-net-shd-hub-npd-swc-001` inside
   `privatelink.blob.core.windows.net`) and leaves the other 24
   untouched.
5. **Resolution test from inside the vnet**: `dig +short
   <storageacct>.blob.core.windows.net` from a VM inside the hub
   vnet returns the private endpoint IP (10.x.x.x range), not the
   public Azure storage IP.

### Edge Cases

- **Empty zone_ids map** (DNS stack applied with
  `disable_catalogue_zones` covering all 25 entries and no
  `custom_zones`): vnet stack MUST still apply cleanly with zero link
  resources — `for_each` over the empty map is a no-op.
- **DNS remote state missing**: if the operator runs
  `terraform/vnet/` before `terraform/dns/` has ever been applied
  (state blob absent), the `data.terraform_remote_state.dns` lookup
  fails fast with a clear backend error — this is acceptable and
  desired (links cannot exist without zones).
- **Concurrent zone add in DNS stack**: a new zone added to the
  catalogue (or via `custom_zones`) in `terraform/dns/` is picked up
  on the NEXT `terraform/vnet/` apply as a strict ADD (one new link
  per vnet per new zone). No manual coordination required beyond
  re-running the vnet stack after the DNS apply.
- **Future multi-subscription split**: when DNS zones eventually move
  to a dedicated subscription distinct from the vnet subscription, the
  link resources MUST continue to be created in the DNS subscription
  (zones are the parents). Implementation MUST source the target
  subscription from the DNS remote-state output rather than assume
  `var.subscription_id`. v1 ships single-subscription but the design
  comment in code MUST flag this evolution.
- **AVM submodule absence**: if AVM
  `avm-res-network-privatednszone ~> 0.5` does not expose a
  vnet-link submodule that can be consumed externally (the parent zone
  is created by the DNS stack, not the vnet stack), the vnet stack
  falls back to the bare `azurerm_private_dns_zone_virtual_network_link`
  resource per Constitution IX's documented-fallback escape.

### Requirements

- **FR-211 — Universal link coverage**: every vnet provisioned by
  `terraform/vnet/` (both `role=hub` and `role=spoke`) MUST create one
  `azurerm_private_dns_zone_virtual_network_link` per zone exposed by
  `data.terraform_remote_state.dns.outputs.zone_ids`. No per-zone
  allow-list / opt-out is exposed in v1 (encoded as C16.1).
- **FR-212 — registration_enabled=false**: every link MUST set
  `registration_enabled = false`. Private-link zones MUST NOT
  autoregister vnet VM hostnames (encoded as C16.2).
- **FR-213 — Link naming**: link resource name MUST be
  `vnetlink-<vnet-name>` (e.g.
  `vnetlink-vnet-net-shd-hub-npd-swc-001`). Names are scoped per
  parent zone, so collisions across vnets are impossible by Azure
  design (encoded as C16.3).
- **FR-214 — Provider/subscription locus**: link resources MUST be
  created against the subscription that owns the parent private DNS
  zones (the DNS subscription). For v1 this is the same subscription
  as the vnet (`883c9081-23ed-4674-95c5-45c74834e093`), but the
  implementation MUST resolve the DNS subscription from the DNS
  remote-state output (not from `var.subscription_id`) so a future
  cross-subscription split needs zero code change beyond a tfvars
  edit (encoded as C16.4).
- **FR-215 — Zone source-of-truth**: zone IDs MUST come from
  `data.terraform_remote_state.dns` (state key per
  `terraform/dns/backend.tf`). No hard-coded zone ID list; no direct
  `azurerm_private_dns_zone` data-source lookup by name from the vnet
  stack (encoded as C16.5).
- **FR-216 — Drift on catalogue shrink**: link `for_each` MUST iterate
  the live `zone_ids` map from remote state — not a static input list
  — so that removing a zone from the DNS catalogue automatically
  destroys the corresponding link on the next vnet apply (encoded as
  C16.6).
- **FR-217 — Idempotency**: re-applying `terraform/vnet/` with
  unchanged inputs and unchanged DNS catalogue MUST produce a zero-change
  plan for the link resources and the `data.terraform_remote_state.dns`
  lookup (encoded as C16.7).
- **FR-218 — Test coverage**: `terraform test` MUST include at minimum
  four `.tftest.hcl` runs asserting (a) `length(links) ==
  length(zone_ids)`, (b) `registration_enabled == false` on every
  link, (c) link names match `vnetlink-<vnet-name>`, (d) empty
  `zone_ids` map applies cleanly with zero link resources. Tests run
  under mocked providers per the existing module test pattern (encoded
  as C16.8).
- **FR-219 — Reusable submodule**: link resources MUST live in a new
  thin submodule `modules/dnslinks/` that takes `vnet_id` + `zone_ids`
  map + (optional) `subscription_id` override. Root stacks consume the
  submodule; future stacks (AKS-private, AML-private, etc.) can reuse
  it without copy-paste. The DNS remote-state lookup itself stays at
  the root-stack layer (not inside the submodule) so the submodule
  remains pure — input-only, no remote state coupling (encoded as
  C16.9).
- **FR-220 — AVM compliance with documented fallback**: the
  implementation MUST first attempt to use AVM
  `Azure/avm-res-network-privatednszone/azurerm ~> 0.5`'s vnet-link
  submodule (if it exposes one consumable from outside the parent
  module). If no such consumable AVM path exists, the submodule falls
  back to the bare `azurerm_private_dns_zone_virtual_network_link`
  resource and documents the fallback decision in
  `modules/dnslinks/README.md` per Constitution IX (encoded as C16.10).
- **FR-221 — Tfvars wiring**: every consuming stack's tfvars file
  (e.g. `variables/hub/npd/vnet.tfvars.json`,
  `variables/sp01/npd/vnet.tfvars.json`) MUST gain a new
  `dns_state_backend` block mirroring the shape of the existing
  `log_state_backend` and `hub_state_backend` blocks:
  `{ subscription_id, resource_group_name, storage_account_name,
  container_name, key }`. Root stack declares
  `var.dns_state_backend` and feeds it into the
  `data.terraform_remote_state.dns` block (encoded as C16.11).
- **FR-222 — Backwards-compat (strict-add plan)**: applying the
  amendment against the already-deployed hub vnet MUST produce a plan
  that only ADDS resources — specifically the new
  `data.terraform_remote_state.dns` data source and the N
  `module.dnslinks.azurerm_private_dns_zone_virtual_network_link.this[*]`
  link resources. Zero destroys, zero replaces, zero in-place changes
  to existing vnet / subnet / NSG / route-table / firewall / bastion
  resources. The pre-merge `terraform plan` output MUST be inspected
  to confirm this before any apply (encoded as C16.12).

### Resolved Clarifications (C16.1..C16.12)

Resolved autonomously per CLAUDE.md ("do not ask the user; encode the
most defensible answers directly into the spec"). All twelve items
below are verbatim from the amendment requester and are the
authoritative answers for implementation.

- **C16.1 — Link scope**: Every vnet (hub + every spoke) links to
  every zone in `terraform_remote_state.dns.outputs.zone_ids`. No
  allow-list, no opt-out per zone in v1.
- **C16.2 — registration_enabled**: Always `false`. These are
  private-link zones; autoregistration is wrong.
- **C16.3 — Link naming**: `vnetlink-<vnet-name>` (one zone-link
  resource per zone, keyed by the zone's catalogue key). Names live
  INSIDE each private DNS zone's namespace so collisions across vnets
  are impossible.
- **C16.4 — Provider/subscription**: Vnet-links are child resources of
  the private DNS zones, so they MUST be created in the DNS
  subscription (the prd-hub subscription that owns the zones). For now
  (single subscription `883c9081-23ed-4674-95c5-45c74834e093`) this is
  the same subscription as the vnet — but the implementation MUST NOT
  assume that; use the DNS remote-state's `subscription_id` if/when
  they diverge. v1 ships single-subscription; the design comment in
  code MUST flag the multi-subscription evolution.
- **C16.5 — Source of zone IDs**:
  `data.terraform_remote_state.dns` (state key `prd/hub/dns.tfstate`
  — verify exact key from `terraform/dns/backend.tf`). The vnet stack
  ALREADY consumes log remote state; add a parallel
  `dns_state_backend` tfvars block.
- **C16.6 — Drift on link removal**: If a zone is removed from the DNS
  catalogue (`disable_catalogue_zones`), the corresponding vnet link
  MUST be auto-destroyed on the next vnet apply (i.e. `for_each` over
  the live `zone_ids` map, not a static list).
- **C16.7 — Idempotency**: Re-apply with unchanged inputs MUST be a
  no-op (zero plan changes).
- **C16.8 — Test coverage**: Add at least 4 `terraform test` runs
  covering: (a) link count equals catalogue zone count, (b)
  registration_enabled=false on every link, (c) link names match
  `vnetlink-<vnet-name>` pattern, (d) when dns remote-state's
  zone_ids is empty the vnet stack still applies with zero link
  resources.
- **C16.9 — Module location**: Add the link resources at the
  `terraform/vnet/` root stack (not inside `modules/network/`),
  because the dns remote-state lookup belongs to the stack layer, not
  the reusable network module. Alternatively, introduce a thin
  `modules/dnslinks/` wrapper that takes `vnet_id` + `zone_ids` map;
  PREFERRED — propose `modules/dnslinks/` so future stacks (e.g. AKS,
  AML private vnets) can reuse.
- **C16.10 — AVM compliance**: Use AVM
  `Azure/avm-res-network-privatednszone/azurerm ~> 0.5` submodule for
  vnet links if it exposes one; otherwise fall back to bare
  `azurerm_private_dns_zone_virtual_network_link` (constitution IX
  allows fallback when no suitable AVM module exists — document the
  decision). VERIFY this by inspecting `modules/dnszones/main.tf` and
  the AVM module's source.
- **C16.11 — Tfvars wiring**: Each consuming stack's tfvars (e.g.
  `variables/hub/npd/vnet.tfvars.json`,
  `variables/sp01/npd/vnet.tfvars.json`) gets a new `dns_state_backend`
  block mirroring the existing `log_state_backend` shape
  (`subscription_id`, `resource_group_name`, `storage_account_name`,
  `container_name`, `key`).
- **C16.12 — Backwards compatibility**: Existing apply of
  `terraform/vnet/` (hub already deployed) MUST be a strict ADD — only
  `module.dnslinks.azurerm_private_dns_zone_virtual_network_link.this[*]`
  resources should appear in the plan, plus the new
  `data.terraform_remote_state.dns` (no destroys, no replaces).

---

## Amendment 2 — Drift Reconciliation (2026-05-30)

### Context

During Phase 8 live rollout (T113) on 2026-05-30 the hub vnet plan
gated at FR-222 with `Plan: 28 to add, 4 to change, 3 to destroy`.
Investigation (evidence in
`temp/scratchpad/hub-drift-2026-05-30.txt`) attributed the unexpected
non-add changes to two classes of Azure-side normalisation that the
original module configuration did not anticipate:

1. **PIP `ip_tags` first-party normalisation** — Azure auto-applies
   `ip_tags = { FirstPartyUsage = "/Unprivileged" }` to Standard SKU
   public IP addresses backing first-party Microsoft services
   (`AzureBastion`, `AzureFirewall`). Because the AVM
   publicipaddress module is silent on `ip_tags`, Terraform sees this
   tag as out-of-band drift on next refresh and treats its removal
   as a `ForceNew` change — destroying and recreating the PIP, which
   in turn forces in-place updates on the bastion host and firewall
   that reference it.
2. **Subnet `serviceEndpoints[].locations` regional expansion** —
   For `Microsoft.Storage` (but not `Microsoft.KeyVault`), Azure
   normalises `locations = ["*"]` to the explicit regional pair (for
   Sweden Central: `["swedencentral", "swedensouth"]`) on the server
   side. The AVM virtualnetwork/subnet submodule round-trips the
   stored value, so every subsequent plan reports a flapping
   in-place update.

The route-table refresh diff (`udr-defaultroute` reappearing as a
`+` route) is **not** drift — it is the legitimate output of
`enable_hub_default_route = true` (FR-210) being applied for the
first time and refresh catching up. No remediation needed; just
documented here for audit.

### Functional Requirements

- **FR-223 — PIP first-party tag explicit declaration.** Every
  Standard SKU `azurerm_public_ip` created by the network stack
  that backs a first-party Microsoft service (firewall data,
  firewall management, bastion) MUST declare
  `ip_tags = { FirstPartyUsage = "/Unprivileged" }` in its
  Terraform configuration so that Azure's auto-applied value is a
  no-op on refresh.
- **FR-224 — Bring-your-own bastion PIP.** Because the AVM bastion
  module (`Azure/avm-res-network-bastionhost/azurerm`) does not
  expose `ip_tags` on its embedded public IP, the bastion submodule
  in `modules/network/bastion/` MUST create the bastion PIP itself
  (using `Azure/avm-res-network-publicipaddress/azurerm`) and pass
  it to the bastion AVM via `create_public_ip = false` +
  `public_ip_address_id`. The externally-managed PIP MUST satisfy
  FR-223 and MUST be named per the existing engine output
  (`local.pip_canonical_names.bas`) — no naming change.
- **FR-225 — Subnet serviceEndpoint locations explicit declaration.**
  For service endpoints that Azure expands `["*"]` into a regional
  list (currently only `Microsoft.Storage`), the wrapper module MUST
  emit the explicit regional list matching the deployment region so
  that refresh is idempotent. The mapping MUST be derived from a
  per-region table keyed by long-form region name and MUST default
  to `["*"]` for any service not in the table (preserving today's
  behaviour for `Microsoft.KeyVault` and any future endpoints that
  Azure does not normalise).

### Clarifications (resolved)

- **C16.13 — Detection strategy**: Drift was detected at the FR-222
  gate (Phase 8 T114). No automated drift watcher is added in this
  amendment — the gate is sufficient. Future work may add a nightly
  CI plan-diff job.
- **C16.14 — `ip_tags` constant value**: The value
  `{ FirstPartyUsage = "/Unprivileged" }` is hard-coded inside the
  bastion + firewall submodules (NOT a tfvars input) because it is a
  property of the consumed first-party service, not of the deployment
  environment. Callers SHALL NOT override.
- **C16.15 — BYO-PIP module location**: The bastion PIP submodule
  call lives **inside** `modules/network/bastion/main.tf` (alongside
  the bastion AVM call) and is wired by the existing
  `public_ip_name` input. The bastion submodule's public interface
  (variables/outputs) is unchanged — only its internal implementation
  is refactored.
- **C16.16 — serviceEndpoint locations table**: Stored as a local
  named `storage_se_locations` in `modules/network/locals.tf`, keyed
  by long-form region name. Initial entries: `swedencentral =
  ["swedencentral", "swedensouth"]`. A `lookup(..., ["*"])` fallback
  guarantees graceful behaviour for regions not yet in the table —
  unknown regions silently fall back to today's `["*"]` behaviour
  and the resulting drift, if any, will be re-detected at the next
  Phase-N gate. No catalogue schema change.
- **C16.17 — Tests required**: At least 3 new tests:
  1. `pip_ip_tags_present` — root-stack plan asserts every
     `azurerm_public_ip.this` resource emitted by the network module
     has `ip_tags = { FirstPartyUsage = "/Unprivileged" }`.
  2. `bastion_byo_pip_wired` — root-stack plan asserts the bastion
     AVM is configured with `create_public_ip = false` and a
     non-null `public_ip_address_id` referencing the in-module PIP.
  3. `subnet_storage_endpoint_regional` — root-stack plan asserts
     that any subnet whose role_catalogue lists `Microsoft.Storage`
     emits `locations = ["swedencentral", "swedensouth"]` for that
     endpoint (and still emits `locations = ["*"]` for
     `Microsoft.KeyVault`).
- **C16.18 — Backwards compatibility**: This amendment MUST be a
  strict zero-diff change for the bastion + firewall resource IDs.
  The refactor in FR-224 changes the Terraform address of the
  bastion PIP from
  `module.network.module.bastion[0].module.bastion.module.public_ip_address[0].azurerm_public_ip.this`
  to
  `module.network.module.bastion[0].module.pip.azurerm_public_ip.this`.
  Phase 9 MUST include a `terraform state mv` step prior to plan so
  the existing Azure resource is preserved (no destroy/recreate).

---

## Amendment: Dedicated Foundry Hosted-Agent subnet role (FR-226)

**Status**: Amendment — appended to feature 004 (engine). Driven by the
Foundry Hosted-Agent network-injection program (see
`specs/006-services/spec.md` FR-031 / CA-013 #3 / VC-5). Engine-only and
purely additive: it adds ONE new entry to the module-internal subnet role
catalogue. No existing role, name, or default changes; no instance consumes
it until a spoke VNet selects it.

### Background (VC-5, from Microsoft Learn `ai-foundry/agents/how-to/virtual-networks`)

A Foundry account with Hosted-Agent network injection requires a **dedicated
agent subnet**:

- delegated to `Microsoft.App/environments`,
- recommended size **/24**,
- **exclusive to a single Foundry account** — it CANNOT be shared with another
  account nor with an Azure Container Apps managed-environment subnet,
- RFC1918 only (CGNAT `100.64/10` is unsupported),
- same region as the account.

The catalogue already has a `container-apps` role (abbr3 `cae`) delegated to
`Microsoft.App/environments`, but that role names the ACA managed-environment
subnet and may be co-selected in the same spoke. Per the exclusivity rule the
agent subnet MUST be a distinct role so a spoke can carry BOTH an ACA subnet
and a separate, dedicated agent subnet without a name/role collision.

### Requirement

- **FR-226 — `agents` subnet role.** The module-internal role catalogue
  (`modules/network/locals.tf`) MUST gain one new role `agents`:

  | Role | Azure-mandated name | Default NSG | Default route table | Default service endpoints | Default delegation |
  |---|---|---|---|---|---|
  | `agents` | (engine-named) | yes | no | — | `Microsoft.App/environments` |

  Fields: `abbr3 = "agt"`, `literal_name = null`, `needs_nsg = true`,
  `needs_route_table = false`, `service_endpoints = []`,
  `delegation = ["Microsoft.App/environments"]`. The subnet is engine-named
  via the existing `subnet` child type (`child_purpose = "agt"`); **no
  naming-engine catalogue (001) change is required** (subnet purposes are
  free-form `abbr3` strings). `needs_route_table = false` mirrors the
  `container-apps` role (the delegated managed-environment handles its own
  egress; attaching the shared spoke 0.0.0.0/0 → firewall route is neither
  required nor recommended for the injected environment). The `agents` key
  MUST also be added to the static `VNET-INV-5` allow-list in
  `modules/network/variables.tf` (the `var.subnets` key validation enumerates
  the permitted roles); the `check.tf` runtime precondition then validates it
  against `keys(local.role_catalogue)` automatically.

### Clarifications — Session 2026-06-02

- **C17 — Distinct role, not a rename of `container-apps`.** The new `agents`
  role is added alongside (not in place of) `container-apps`. A spoke may
  select either, both, or neither. This honours VC-5 exclusivity: the ACA
  environment subnet (`cae`) and the Foundry agent subnet (`agt`) are
  separately named, separately delegated subnet instances.
- **C18 — /24 sizing is an instance concern.** The catalogue defines the role
  and its delegation only; the actual CIDR (recommended /24) is supplied by
  the instance VNet's `var.subnets` map (e.g. the `102-sp01-npd-vnet`
  address-space expansion, CA-013 #4). The engine does not pin a size.
- **C19 — Engine-only, default-off in practice.** No `var.subnets` map in any
  current instance lists `agents`, so this amendment changes nothing live
  until an instance VNet opts in. Day-one parity preserved.

### Test plan (amendment)

- `modules/network/tests/agents_role_delegation.tftest.hcl` — a spoke plan
  with `subnets` including `"agents" = "<cidr>"` asserts (a) the agent subnet
  is emitted with delegation `Microsoft.App/environments`, (b) it carries an
  NSG, (c) it does NOT attach the shared route table, and (d) the engine
  emits the `snet-…-agt-…` canonical name. Reuses the existing mocked,
  `-backend=false` module-test harness.

### Out of scope for FR-226

Address-space expansion / CIDR selection (CA-013 #4, the `102` instance), the
Foundry account wiring that consumes the subnet id (006 FR-031, already
merged), and any live apply.
