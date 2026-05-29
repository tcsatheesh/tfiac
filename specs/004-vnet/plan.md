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
