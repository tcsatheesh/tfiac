# modules/network/

Engine-driven hub-or-spoke network module. Authored under feature 004.

## What it creates

For any stack:

- Per-stack `azurerm_resource_group` (`rg-<tenant>-<env>-<region>-001`).
- One `azurerm_virtual_network` (`vnet-<tenant>-<env>-<region>-001`)
  with caller-supplied `address_space`.
- One `azurerm_subnet` per role in `var.subnets`. Subnet names are
  engine-purpose-keyed (`snet-<role>-...`) **except** for
  `bastion` / `firewall` / `firewall-mgmt` which must use Azure-mandated
  literal names (`AzureBastionSubnet`, etc.) — the module enforces this
  automatically from the role catalogue.
- One `azurerm_network_security_group` per subnet role whose catalogue
  entry has `add_nsg = true`. NSGs are tagged with `subnet_role = <role>`
  so they remain easy to identify even though their canonical names are
  positionally numbered (`nsg-<tenant>-<env>-<region>-NNN`).
- A baseline rule set on the `bastion` NSG covering the Azure-mandated
  inbound/outbound rules.
- One `azurerm_route_table` (only emitted when at least one requested
  role wants `add_route_table = true`) with an optional default route
  `0.0.0.0/0 → var.default_route_next_hop_ip`.

## Optional submodules

- `modules/network/bastion/` — call from the hub stack when
  `enable_bastion = true`. Takes `subnets.bastion` as its target subnet.
- `modules/network/firewall/` — call from the hub stack when
  `enable_firewall = true`. Provisions Azure Firewall + management PIP
  + data PIP using an empty policy (rule collections are a deferred
  feature 005 deliverable).

## Inputs

| Var | Type | Notes |
|---|---|---|
| `naming` | `map(any)` | passthrough |
| `by_type` | `map(list(string))` | passthrough |
| `region` / `region_code` | strings | |
| `input` | engine input object | for tags |
| `address_space` | `list(string)` | |
| `subnets` | `map(string)` | role => CIDR |
| `extra_nsg_rules` | `map(any)` | role => list of azurerm_network_security_rule attrs |
| `enable_bastion` / `enable_firewall` | bool | drives capacity hints only — submodules are called from the root |
| `default_route_next_hop_ip` | string | wired post-firewall in the hub stack |

## Supported subnet roles

`development`, `pre-production`, `api-management`, `buildsvr`,
`bastion`, `firewall`, `firewall-mgmt`, `function-app`, `logic-app`,
`pre-production-function-app`, `pre-production-logic-app`.

## Known scope boundaries

- NSG canonical names are numerically suffixed (`-001`, `-002`, ...)
  because the engine top-level catalogue doesn't yet support
  purpose-keyed naming for `nsg`. The deterministic mapping
  `local.nsg_name_for[role]` is the authoritative lookup.
- Custom APIM NSG rules and firewall rule collections are deferred to
  feature 005 (will land via `var.extra_nsg_rules["api-management"]` and
  a firewall-policy module respectively).
