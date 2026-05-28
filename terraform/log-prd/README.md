# terraform/log-prd/ — Centralized Log Analytics for prd hub

Feature 003. Provisions the **prd-side** centralized Log Analytics Workspace
(`log-hub-prd-sdc-001`) and its resource group. Sinks logs from all
prd workloads (prd spokes and the prd hub itself, including DNS diagnostics).

## Inputs

| Var | Type | Default |
|---|---|---|
| `subscription_id` | GUID | — |
| `region` | string | — (allowlist: `swedencentral`) |
| `repo` | string | — |
| `retention_in_days` | number | `30` |
| `sku` | string | `PerGB2018` |

## Outputs

`workspace_id`, `workspace_name`, `resource_group_name`.

## Consuming from a producer stack

```hcl
data "terraform_remote_state" "log_prd" {
  backend = "local"
  config  = { path = "../log-prd/terraform.tfstate" }
}

resource "azurerm_monitor_diagnostic_setting" "x" {
  log_analytics_workspace_id = data.terraform_remote_state.log_prd.outputs.workspace_id
  # ...
}
```

## Tests

```sh
cd terraform/log-prd && terraform test
```
