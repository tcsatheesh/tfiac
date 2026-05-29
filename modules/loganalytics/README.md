# modules/loganalytics

Thin wrapper over `Azure/avm-res-operationalinsights-workspace/azurerm ~> 0.5`
that creates a centralised Log Analytics workspace (and its parent RG via
`Azure/avm-res-resources-resourcegroup/azurerm ~> 0.4`) in the npd-hub and
prd-hub subscriptions.

Feature spec: [specs/003-log-analytics/](../../specs/003-log-analytics/).

## Inputs

| Name | Type | Default | Required | Constraint |
|---|---|---|---|---|
| `input` | object | — | yes | engine input bundle `{tenant, environment, region, usecase, stack_purpose, repo}` |
| `workspace_key` | string | `"central"` | no | regex `^[a-z0-9]{1,16}$` |
| `retention_in_days` | number | `30` | no | `30 ≤ x ≤ 730` (LOG-INV-6) |
| `daily_quota_gb` | number | `-1` | no | `-1` (unlimited) or `>= 1` (LOG-INV-7) |

## Outputs

| Name | Sensitive | Notes |
|---|---|---|
| `workspace_id` | yes | Customer GUID for SDK/CLI wiring (FR-106) |
| `workspace_resource_id` | no | Azure resource id for `azurerm_monitor_diagnostic_setting` |
| `workspace_name` | no | Engine-emitted canonical name (LOG-INV-11) |
| `resource_group_name` | no | Engine-emitted RG name |
| `resource_group_id` | no | Azure resource id of the RG |
| `primary_shared_key` | **yes** | Workspace primary shared key (LOG-INV-10) |
| `naming` | no | Full naming-engine `names` map for the stack |

## Hard fails

- `var.retention_in_days` outside `[30, 730]` (LOG-INV-6, FR-105)
- `var.daily_quota_gb` is `0` or `< -1` (LOG-INV-7, FR-105)
- `var.workspace_key` outside `^[a-z0-9]{1,16}$`
- Naming-engine snapshot bypass: `check.tf` preconditions fail if the engine
  does not emit both expected canonical names (LOG-INV-9)

## Snapshot fixtures

Drift-detection baselines live in [tests/fixtures/](tests/fixtures/) — see the
[fixtures README](tests/fixtures/README.md) for regeneration instructions.

## AVM modules

| Module | Pin |
|---|---|
| `Azure/avm-res-resources-resourcegroup/azurerm` | `~> 0.4` |
| `Azure/avm-res-operationalinsights-workspace/azurerm` | `~> 0.5` |

`enable_telemetry = false` is set on both per Constitution IX.

## Local verification

```bash
cd modules/loganalytics
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```
