# `modules/network/peering` — Constitution IX exception

This submodule deliberately uses **native `azurerm_virtual_network_peering`
resources** rather than an AVM module.

## Why this exception is necessary

A hub-and-spoke peering is symmetric: a peering resource must exist on both
sides of the link. In day-one deployments the hub vnet lives in a different
Azure subscription from the spoke vnet, which means we need **two providers
with different `subscription_id` values** to create the two halves.

AVM virtualnetwork modules accept a single provider implicitly. There is no
supported AVM module that takes a `providers = { azurerm.local, azurerm.hub }`
mapping for cross-subscription peering, so wrapping it as AVM would force one
side of the peering into the wrong subscription (or require us to fall back to
ARM/azapi calls that hand-roll the equivalent).

The native `azurerm_virtual_network_peering` resource is the simplest, most
explicit way to express "one peering on this provider, one on that one". The
contract is tiny and stable.

## Inputs

The submodule expects identifiers for **both** vnets and is wired by the root
stack:

* `spoke_*` — passed via the `azurerm.this` provider (the spoke's own subscription)
* `hub_*` — passed via the `azurerm.hub` provider (the hub's subscription)

See `variables.tf` for the full list.

## Review checklist

* No AVM module exists that meets the cross-subscription peering need — verified
  against the AVM module index (terraform-avm-virtualnetwork peerings are
  in-subscription only or rely on `create_reverse_peering`, which still uses
  the calling provider).
* Both sides of the peering are kept symmetric (same `allow_*` flags).
* The wrapper module (`modules/network`) does **not** import this submodule;
  it is invoked from the root stack (`terraform/vnet`) only when
  `var.role == "spoke"`.
