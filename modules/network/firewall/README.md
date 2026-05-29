# `modules/network/firewall`

Thin wrapper around the AVM `Azure/avm-res-network-azurefirewall/azurerm`
module (AZFW_VNet SKU, Standard tier). Used only when the parent network
module's `role == "hub"`.

Creates:

* Two Standard/Static zonal PIPs (`data` + `management`) via the AVM PIP module.
* An empty `azurerm_firewall_policy` (Standard tier) — **Constitution IX
  exception**: there is no AVM module for the firewall policy resource and
  the AVM firewall module only accepts a pre-existing `policy_id`. The empty
  policy is intentionally minimal (day-one per spec C5) and lives inline so
  the policy lifecycle stays bound to the firewall it backs.
* The firewall itself, wired to both subnets and both PIPs.

The data-plane private IP is exported and consumed by spokes to populate the
`0.0.0.0/0 -> VirtualAppliance` default route on their route table.

## Inputs

See [variables.tf](variables.tf).

## Outputs

* `resource_id` — firewall id
* `private_ip` — data-plane private IP (consumed by spoke RTs)
* `policy_id` — empty Standard policy id
