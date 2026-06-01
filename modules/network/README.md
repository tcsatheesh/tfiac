# `modules/network` — vnet wrapper

AVM-backed wrapper that composes one Azure vnet plus its NSGs, route table,
and (hub-only) bastion + firewall, named by the [naming engine](../naming).

## Inputs

| Name | Purpose |
|------|---------|
| `input` | Engine input bundle. `stack_purpose` must be `"net"`. |
| `role` | `"hub"` enables bastion + firewall; `"spoke"` adds a default-route to the hub firewall. |
| `address_space` | List of CIDRs for the vnet (>=1). |
| `subnets` | Map of subnet role => CIDR. Roles must come from the [role catalogue](#role-catalogue). |
| `extra_nsg_rules` | Reserved per-role NSG rule extensions (passthrough to AVM `security_rules`). |
| `hub_vnet_id` / `hub_firewall_private_ip` / `hub_subscription_id` | Spoke-only inputs supplied by the root stack from the hub's remote state. |

## Outputs

See [outputs.tf](outputs.tf). Notable entries:

* `vnet_id`, `vnet_name`, `subnets` (map keyed by role), `nsgs`, `route_table_id`/`name`.
* `firewall_private_ip`, `firewall_id`, `bastion_id` — hub only; `null` on spoke.
* `resource_group_name`/`_id`, `naming` (full engine map).

## Role catalogue

Defined in [locals.tf](locals.tf#L4). Each role declares an `abbr3`, whether it
needs an NSG and route-table association, plus any service endpoints and
delegations:

| Role | abbr3 | NSG? | RT? | Special |
|------|-------|-----|-----|---------|
| `development` | dev | yes | yes | Storage + KeyVault endpoints |
| `pre-production` | pre | yes | yes | Storage + KeyVault endpoints |
| `api-management` | api | yes | no  | |
| `buildsvr` | bld | yes | yes | |
| `function-app` | fnc | yes | yes | delegated to `Microsoft.Web/serverFarms` |
| `logic-app` | lgc | yes | yes | delegated to `Microsoft.Web/serverFarms` |
| `preprod-func` | pfn | yes | yes | delegated to `Microsoft.Web/serverFarms` |
| `preprod-logic` | plg | yes | yes | delegated to `Microsoft.Web/serverFarms` |
| `container-apps` | cae | yes | no  | delegated to `Microsoft.App/environments` |
| `bastion` | bas | yes | no  | literal name `AzureBastionSubnet` |
| `firewall` | afw | no  | no  | literal name `AzureFirewallSubnet` |
| `firewall-mgmt` | afm | no  | no  | literal name `AzureFirewallManagementSubnet` |

## Invariants (enforced)

* VNET-INV-3: `role` ∈ {hub, spoke}
* VNET-INV-5: subnet keys must be in the role catalogue (variable validation)
* VNET-INV-8: snapshot — engine emits the locally-computed canonical names
* VNET-INV-9: `address_space` >=1 valid CIDR
* VNET-INV-10: hub requires `bastion` + `firewall` + `firewall-mgmt` subnets

## Submodules

* [`bastion/`](bastion/README.md) — AVM bastion (Standard SKU) + PIP.
* [`firewall/`](firewall/README.md) — AVM firewall (Standard tier) + 2× PIP + empty policy.
* [`peering/`](peering/README.md) — **Constitution IX exception**: native
  `azurerm_virtual_network_peering` for cross-subscription peering. Invoked by
  the root stack on `role=spoke` only.

## Testing

`terraform test` from this directory runs 7 tests (positive baselines for hub
and spoke + 5 negatives). See [tests/](tests/) and the snapshot fixtures
under [tests/fixtures/](tests/fixtures/README.md).
