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
