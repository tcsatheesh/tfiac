# `modules/network/bastion`

Thin wrapper around the AVM `Azure/avm-res-network-bastionhost/azurerm` module
(Standard SKU). Used only when the parent network module's `role == "hub"`.

The AVM module creates its own public IP when `create_public_ip = true`; the
engine-emitted canonical PIP name is passed via `public_ip_address_name` so
the resource ends up with the right name.

## Inputs

See [variables.tf](variables.tf).

## Outputs

* `resource_id` — bastion id
* `name` — bastion name
