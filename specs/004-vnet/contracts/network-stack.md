# Contract — `modules/network/` + `terraform/vnet/`

## modules/network/

### Inputs

| Name | Type | Required | Default | Constraint |
|---|---|---|---|---|
| `input` | engine input bundle | yes | — | tenant/environment/region/usecase/stack_purpose/repo |
| `role` | string | yes | — | `"hub"` or `"spoke"` |
| `address_space` | list(string) | yes | — | ≥1; every entry parses via `cidrhost(.,0)` |
| `subnets` | map(string) | yes | — | role keys in `local.role_catalogue` |
| `extra_nsg_rules` | map(list(object)) | no | `{}` | role keys in catalogue |
| `hub_vnet_id` | string | spoke only | `null` | `^/subscriptions/...` |
| `hub_firewall_private_ip` | string | spoke only | `null` | IPv4 |
| `hub_subscription_id` | string | spoke only | `null` | GUID |

### Outputs

See [data-model.md § module.network outputs](../data-model.md#modulenetwork-outputs).

### Invariants (`check.tf`)

| ID | Condition |
|---|---|
| VNET-INV-3 | `var.role ∈ {"hub","spoke"}` |
| VNET-INV-5 | Every `keys(var.subnets)` is in `local.role_catalogue` |
| VNET-INV-9 | `length(var.address_space) >= 1` |
| VNET-INV-10 | `role=="hub"` ⇒ `bastion`, `firewall`, `firewall-mgmt` all present in `var.subnets` |
| VNET-INV-snapshot | naming engine emits expected vnet + RG canonical names (LOG-INV-9 pattern) |

## terraform/vnet/

### Inputs

| Name | Source | Constraint |
|---|---|---|
| `subscription_id` | env (TF_VAR) | GUID |
| `repo` | env (TF_VAR) | `<org>/<repo>` |
| `region` | tfvars | must be `"swc"` (VNET-INV-1) |
| `tenant` | tfvars | `^(hub\|sp[0-9]{2})$` |
| `environment` | tfvars | `"npd"` or `"prd"` (VNET-INV-2) |
| `role` | tfvars | `"hub"` or `"spoke"` (VNET-INV-3) |
| `address_space` | tfvars | as above |
| `subnets` | tfvars | as above |
| `extra_nsg_rules` | tfvars | as above (default `{}`) |
| `hub_state_backend` | tfvars | required if role=spoke; `null` if role=hub (VNET-INV-6, VNET-INV-7) |
| `usecase` | tfvars | default `"shd"` |

### Outputs

1:1 re-export of `module.network` outputs (see data-model).

### Behaviour

- `data "azurerm_client_config" "current"`
- `check "subscription_match"` (VNET-INV-4)
- If `role==spoke`: `data "terraform_remote_state" "hub"` reads from `var.hub_state_backend`
- Single `module "network"` instance, conditional inputs

### State backend

azurerm + `use_azuread_auth = true`; key injected at init (`hub/npd/vnet.tfstate` or `sp01/npd/vnet.tfstate`).
