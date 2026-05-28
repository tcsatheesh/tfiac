# terraform/log-npd/ — Centralized Log Analytics for npd hub

Feature 003. Provisions the **npd-side** centralized Log Analytics Workspace
(`log-hub-npd-sdc-001`) and its resource group. Sinks logs from all
non-prd workloads (npd, dev, pre spokes).

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
data "terraform_remote_state" "log_npd" {
  backend = "local"
  config  = { path = "../log-npd/terraform.tfstate" }
}

resource "azurerm_monitor_diagnostic_setting" "x" {
  log_analytics_workspace_id = data.terraform_remote_state.log_npd.outputs.workspace_id
  # ...
}
```

## Tests

```sh
cd terraform/log-npd && terraform test
```
