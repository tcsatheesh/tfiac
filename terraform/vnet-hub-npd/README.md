# terraform/vnet-hub-npd/

Feature 004 — npd hub vnet stack. Provisions vnet `vnet-hub-npd-sdc-001`
(`10.240.4.0/23`) with 7 subnets, Azure Bastion, Azure Firewall (Standard,
empty policy), per-subnet NSGs, and the central route table that sends
`0.0.0.0/0` to the firewall private IP.

## Layout

| Role | CIDR | Subnet name | NSG? | Routed via firewall? |
|---|---|---|---|---|
| `development` | 10.240.4.0/26 | `snet-development-hub-npd-sdc-001` | ✓ | ✓ |
| `pre-production` | 10.240.4.64/26 | `snet-pre-production-hub-npd-sdc-001` | ✓ | ✓ |
| `api-management` | 10.240.4.144/28 | `snet-api-management-hub-npd-sdc-001` | ✓ | — |
| `buildsvr` | 10.240.4.160/28 | `snet-buildsvr-hub-npd-sdc-001` | ✓ | ✓ |
| `bastion` | 10.240.4.192/28 | `AzureBastionSubnet` | ✓ (baseline rules) | — |
| `firewall` | 10.240.5.0/26 | `AzureFirewallSubnet` | — | — |
| `firewall-mgmt` | 10.240.5.64/26 | `AzureFirewallManagementSubnet` | — | — |

## Tests

```sh
cd terraform/vnet-hub-npd && terraform test
```
