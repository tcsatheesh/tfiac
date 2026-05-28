# terraform/vnet-sp01-npd/

Feature 004 — npd sp01 spoke vnet stack. Provisions vnet
`vnet-sp01-npd-sdc-001` (`10.240.2.0/24`) with 6 subnets, per-subnet
NSGs, a route table that forwards `0.0.0.0/0` to the hub firewall, and
a vnet peering to `vnet-hub-npd-sdc-001`.

Hub coupling: reads `vnet_id` and `firewall_private_ip` via
`terraform_remote_state` against `../vnet-hub-npd/terraform.tfstate`.
For tests, both values are supplied as variables.

```sh
cd terraform/vnet-sp01-npd && terraform test
```
