# Producer Contract — `terraform/log/` stack

This document is the published, stable interface that downstream stacks
(DNS, vnet, NSG, firewall, services, fnapp, openai, etc.) consume via
`data "terraform_remote_state" "log_<env>"`. Any change to this contract
is a breaking change and requires a major spec revision.

## State location

The stack has two equally-canonical state files — one per hub
environment. Consumers MUST reference the env that matches the workload
they are wiring (npd workloads → npd workspace; prd workloads + prd-hub
itself → prd workspace).

| Field | npd | prd |
|-------|-----|-----|
| Backend | `azurerm` | `azurerm` |
| State key | `hub/npd/log.tfstate` | `hub/prd/log.tfstate` |
| `use_azuread_auth` | `true` | `true` |
| Subscription | `var.subscription_id` (npd) — verified against current az session at plan time | `var.subscription_id` (prd) — verified at plan time |

## Inputs (root-stack surface)

| Name | Type | Default | Notes |
|------|------|---------|-------|
| `subscription_id` | `string` | — | UUID. Cross-checked against current Azure session (LOG-INV-5). |
| `region` | `string` | — | MUST equal `"swc"` (LOG-INV-1). |
| `repo` | `string` | — | Flows into tag `repo`. |
| `topology` | `string` | — | MUST equal `"hub"` (LOG-INV-2). |
| `tenant` | `string` | — | MUST equal `"hub"` (LOG-INV-3). |
| `environment` | `string` | — | MUST be `"npd"` or `"prd"` (LOG-INV-4). |
| `retention_in_days` | `number` | `30` | Integer in `[30, 730]` (LOG-INV-6). |
| `daily_quota_gb` | `number` | `-1` | `-1` (unlimited) OR positive integer (LOG-INV-7). |
| `workspace_key` | `string` | `"central"` | Internal naming-engine map key; NOT the Azure resource name. |

## Outputs (consumer-facing)

| Output | Type | Sensitive | Stability guarantee |
|--------|------|-----------|---------------------|
| `workspace_id` | `string` | no | GUID. Stable for the lifetime of the workspace; recreating the workspace (e.g. region move) is a breaking event. |
| `workspace_resource_id` | `string` | no | Full Azure ARM resource id. Used for `log_analytics_workspace_id` on `azurerm_monitor_diagnostic_setting`. Stable across `terraform apply` runs with unchanged inputs. |
| `workspace_name` | `string` | no | Engine-emitted: derived per the `hyphenated` shape `{abbr}-{service_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}` → `log-shd-shd-hub-<env>-swc-001`. Byte-stable across reruns (LOG-INV-11). |
| `resource_group_name` | `string` | no | Engine-emitted: `rg-log-shd-hub-<env>-swc-001`. |
| `resource_group_id` | `string` | no | Full Azure resource id of the per-stack RG. |
| `primary_shared_key` | `string` | **yes** | The workspace shared key; surfaced via `terraform output -json` only with `-no-color` + explicit `terraform output primary_shared_key` and NEVER printed in CI logs (LOG-INV-10). |
| `naming` | `object` | no | Passthrough of `module.naming` — gives consumers the same `names` / `region_full` / `engine_version` they would get if they instantiated the engine themselves. |

## Consumer pattern

```hcl
# Pick the env that matches your workload
data "terraform_remote_state" "log" {
  backend = "azurerm"
  config = {
    resource_group_name  = "<state-rg>"
    storage_account_name = "<state-sa>"
    container_name       = "<state-container>"
    key                  = var.environment == "prd" ? "hub/prd/log.tfstate" : "hub/npd/log.tfstate"
    use_azuread_auth     = true
  }
}

# 1. Wire a diagnostic setting
resource "azurerm_monitor_diagnostic_setting" "x" {
  name                       = "diag-${each.key}"
  target_resource_id         = azurerm_some_resource.this[each.key].id
  log_analytics_workspace_id = data.terraform_remote_state.log.outputs.workspace_resource_id

  enabled_log { category_group = "allLogs" }
  metric      { category       = "AllMetrics" }
}

# 2. Surface the GUID for a Log Analytics agent install
locals {
  ama_workspace_id = data.terraform_remote_state.log.outputs.workspace_id
}
```

## Hard-fail catalogue (plan-time, FR-* → user-visible message)

| Trigger | FR / INV | Message (verbatim shape) |
|---------|----|--------------------------|
| `topology != "hub"` | LOG-INV-2 | `topology must be "hub" for the centralized log analytics stack; got "<value>"` |
| `tenant != "hub"` | LOG-INV-3 | `tenant must be "hub" for the centralized log analytics stack; got "<value>"` |
| `environment ∉ {"npd","prd"}` | LOG-INV-4 | `environment must be one of ["npd","prd"]; got "<value>"` |
| `region != "swc"` | LOG-INV-1 | `region must be "swc" (swedencentral) for the centralized log analytics stack; got "<value>"` |
| `var.subscription_id != current session subscription` | LOG-INV-5 / FR-109 | `var.subscription_id <X> does not match the current az session subscription <Y>; re-authenticate or correct the input` |
| `retention_in_days < 30` or `> 730` | LOG-INV-6 | `retention_in_days must be an integer in [30, 730]; got <value>` |
| `daily_quota_gb == 0` or `< -1` | LOG-INV-7 | `daily_quota_gb must be -1 (unlimited) or a positive integer; got <value>` |

## Compatibility (semantic-version policy for this contract)

| Change type | Allowed without spec bump |
|-------------|---------------------------|
| Add new optional input with a backwards-compatible default | ✅ (additive) |
| Add new output | ✅ (additive) — consumers using `outputs.<existing>` are unaffected. |
| Tighten an input validation in a way that REJECTS values previously accepted | ❌ — breaking |
| Loosen an input validation | ✅ (additive) |
| Rename or remove an existing output | ❌ — breaking |
| Change an output's type or `sensitive` flag (e.g. unmarking `primary_shared_key`) | ❌ — breaking |
| Change the engine-emitted `workspace_name` / `resource_group_name` literal | ❌ — breaking (forces workspace/RG destroy + recreate; consumers of `workspace_id` lose history) |
| Bump AVM module to a new minor within `~> 0.x` | ✅ (within the documented pin) — PR must re-run snapshot tests. |
| Bump AVM module ACROSS the `~> 0.x` boundary (e.g. `0.x` → `0.(x+1)` or `0.x` → `1.x`) | ⚠️ requires PR + manual snapshot regen + contract review |
| Add a third environment (`pre`, `tst`, …) | ⚠️ requires LOG-INV-4 widening + new tfvars + new state key + new snapshot fixture; not breaking for existing consumers but explicitly out of scope in v1 |

## Telemetry

AVM modules can emit `modtm_telemetry` resources by default. The wrapper
sets `enable_telemetry = false` on both AVM calls (research D2 / LOG-INV-12).
This is a deliberate divergence from feature 002 and is documented as a
property of the contract: this stack will NEVER create
`modtm_telemetry.telemetry_metadata` resources, and consumers MUST NOT
depend on their presence.

## Cross-environment guarantees

| Statement | Holds? |
|---|---|
| Both envs publish the SAME output schema (field names, types, sensitivities). | ✅ |
| Both envs publish DIFFERENT `workspace_name` / `resource_group_name` literals (parameterised by `<env>`). | ✅ |
| A change to the npd state has zero effect on the prd state (and vice versa). | ✅ — two independent state files, no Terraform cross-reference. |
| The two state files MAY live in the same Storage account container. | ✅ — Constitution VII allows this; the `key` path scheme keeps them logically separated. |
