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
