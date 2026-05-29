# Feature 004 — Hub & Spoke Network Foundation

**Status**: Implemented on master alongside spec.

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
