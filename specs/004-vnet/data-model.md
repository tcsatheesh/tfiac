# Data Model — Feature 004 — Hub & Spoke Network Foundation

## Entities

### `module.network` (wrapper) inputs

| Name | Type | Required | Notes |
|---|---|---|---|
| `input` | engine object | yes | `{tenant, environment, region, usecase, stack_purpose="net", repo}` |
| `role` | string | yes | `"hub"` or `"spoke"` |
| `address_space` | list(string) | yes | ≥1 CIDR |
| `subnets` | map(string) | yes | `{ role => cidr }` |
| `extra_nsg_rules` | map(list(object)) | no | `{ role => [rule_object] }`; default `{}` |
| `hub_vnet_id` | string | spoke only | passed by root stack from remote state |
| `hub_firewall_private_ip` | string | spoke only | passed by root stack from remote state |
| `hub_subscription_id` | string | spoke only | passed by root stack from `var.hub_state_backend` |

### `module.network` outputs

| Name | Type | Notes |
|---|---|---|
| `vnet_id` | string | resource id |
| `vnet_name` | string | engine-emitted |
| `vnet_address_space` | list(string) | as deployed |
| `subnets` | map(object) | role → `{ id, name, address_prefix }` |
| `nsgs` | map(object) | role → `{ id, name }` |
| `route_table_id` | string |  |
| `route_table_name` | string |  |
| `firewall_private_ip` | string \| null | hub only |
| `firewall_id` | string \| null | hub only |
| `bastion_id` | string \| null | hub only |
| `resource_group_name` | string | engine-emitted |
| `resource_group_id` | string |  |
| `naming` | map | engine `names` map |

### Subnet role catalogue (module-internal)

See [research.md D11](research.md#d11-subnet-role--3-char-service_purpose-abbr-map) for the role→abbr map. Each entry in `local.role_catalogue` is:

```hcl
{
  abbr3                 = string         # 3-char service_purpose
  literal_name          = string|null    # Azure-mandated name; null → engine-named
  needs_nsg             = bool
  needs_route_table     = bool
  service_endpoints     = list(string)
  delegation            = list(object)   # azurerm subnet delegation
  bastion_or_firewall   = bool           # special handling at hub
}
```

### Root stack `terraform/vnet/` inputs

See plan.md § Inputs. The root stack is a thin wrapper that:
1. Validates `var.region`, `var.role`, `var.environment`, `var.subscription_id` match.
2. If `role=spoke`, reads `data.terraform_remote_state.hub`.
3. Calls `module.network` with the appropriate hub_* arguments.
4. Re-exports the wrapper's outputs 1:1.

### Engine usage

Constructed dynamically in `modules/network/locals.tf`:

```hcl
engine_services = concat(
  [{ service_type = "resource_group", key = "main", stack_purpose = "net" }],
  [{ service_type = "vnet", key = "main", service_purpose = "net" }],
  [{ service_type = "route_table", key = "rt", service_purpose = "fw" }],
  [for role, _ in var.subnets : {
    service_type    = "nsg"
    key             = local.role_catalogue[role].abbr3
    service_purpose = local.role_catalogue[role].abbr3
  } if local.role_catalogue[role].needs_nsg],
  var.role == "hub" ? [
    { service_type = "public_ip", key = "bas", service_purpose = "bas" },
    { service_type = "public_ip", key = "afw", service_purpose = "afw" },
    { service_type = "public_ip", key = "afm", service_purpose = "afm" },
  ] : [],
)

engine_children = concat(
  [for role, _ in var.subnets : {
    service_type  = "subnet"
    parent_key    = "main"        # vnet key
    key           = local.role_catalogue[role].abbr3
    child_purpose = local.role_catalogue[role].abbr3
  }],
  var.role == "hub" ? [
    { service_type = "vnet_bastion",  parent_key = "main", key = "bas" },
    { service_type = "vnet_firewall", parent_key = "main", key = "afw" },
  ] : [],
)
```

## State

| Stack | Backend path | Key outputs |
|---|---|---|
| `terraform/vnet/` (`hub/npd/vnet.tfstate`) | azurerm + AAD | `vnet_id`, `vnet_name`, `firewall_private_ip` (read by spoke) |
| `terraform/vnet/` (`sp01/npd/vnet.tfstate`) | azurerm + AAD | `vnet_id`, `vnet_name` |

## Dependencies (apply order)

1. `hub/npd/vnet.tfstate` — must exist before `sp01/npd/vnet.tfstate` plans (peering target + firewall private IP).
2. Within each stack: RG → vnet (creates subnets) → NSGs → RT → bastion/firewall/peering submodules (parallel where independent).
