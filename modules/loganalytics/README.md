# modules/loganalytics/

Thin module that creates a per-stack resource group + a single Log Analytics
Workspace using engine-canonical names. Authored under feature 003.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `naming` | `map(any)` | — | Passthrough of `module.naming.names`. |
| `region` | `string` | — | Azure region. |
| `region_code` | `string` | — | Engine-mapped short code (e.g. `sdc`). |
| `input` | engine input object | — | For baseline tags. |
| `retention_in_days` | `number` | `30` | 30..730. |
| `sku` | `string` | `PerGB2018` | Workspace SKU. |

## Outputs

| Name | Description |
|---|---|
| `workspace_id` | Azure resource ID. |
| `workspace_name` | Canonical name (e.g. `log-hub-prd-sdc-001`). |
| `resource_group_name` | RG name. |
| `resource_group_id` | RG ID. |
| `workspace_primary_shared_key` | Sensitive. |

## Usage

```hcl
module "log" {
  source      = "../../modules/loganalytics"
  naming      = module.naming.names
  region      = var.region
  region_code = local.region_codes[var.region]
  input       = local.input
}
```
