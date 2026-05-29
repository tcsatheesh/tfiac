# Phase 1 — Data Model: Centralized Log Analytics Workspaces (003)

## Entities

### 1. EngineNamingInput

The intent bundle fed to `module "naming"` from `terraform/log/locals.tf`.
Constructed once per apply from the root-stack variables.

| Field | Type | Constraint / Source |
|-------|------|---------------------|
| `input.subscription_id` | `string` | UUID; cross-checked vs current `data.azurerm_client_config.current.subscription_id` (LOG-INV-5). |
| `input.region` | `string` | MUST equal `"swc"` (LOG-INV-1). |
| `input.repo` | `string` | Flows into tag `repo`. |
| `input.topology` | `string` | MUST equal `"hub"` (LOG-INV-2). |
| `input.tenant` | `string` | MUST equal `"hub"` (LOG-INV-3). |
| `input.environment` | `string` | MUST be one of `["npd", "prd"]` (LOG-INV-4). |
| `input.usecase` | `string` | Wrapper constant `"shd"` (research D5). |
| `input.stack_purpose` | `string` | Wrapper constant `"log"` (research D5). |
| `input.managed_by` | `string` | Wrapper constant `"terraform"`. |
| `services[0].service_type` | `string` | Hard-coded `"log_analytics"`. |
| `services[0].key` | `string` | `var.workspace_key`, default `"central"`. |
| `services[0].service_purpose` | `string` | Hard-coded `"shd"` (research D5). |
| `services[1].service_type` | `string` | Hard-coded `"resource_group"`. |
| `services[1].key` | `string` | Hard-coded `"main"`. |
| `services[1].stack_purpose` | `string` | Inherits from `input.stack_purpose` (engine default). |

Storage: `local.naming_input` in `terraform/log/locals.tf`.

### 2. EffectiveStack

The result of fully resolving the engine outputs for the
`(topology, tenant, environment)` tuple at hand. There is exactly one
EffectiveStack per `terraform init`/`apply` cycle.

| Field | Type | Source |
|-------|------|--------|
| `workspace_name` | `string` | `module.naming.names[<workspace_key>].name` → `log-shd-shd-hub-<env>-swc-001` (literal locked by snapshot — research D5/D9). |
| `workspace_tags` | `map(string)` | `module.naming.names[<workspace_key>].tags` (eight baseline tags). |
| `resource_group_name` | `string` | `module.naming.names[<rg_key>].name` → `rg-log-shd-hub-<env>-swc-001`. |
| `resource_group_tags` | `map(string)` | `module.naming.names[<rg_key>].tags`. |
| `region_full` | `string` | `module.naming.region_full` → `"swedencentral"` (engine resolves `"swc"`). |
| `state_key` | `string` | `"hub/${var.environment}/log.tfstate"` — supplied at `terraform init` via `-backend-config` (research D4); represented as a derived local for snapshot purposes only. |

Storage: derived in `terraform/log/locals.tf` and `modules/loganalytics/locals.tf`.

### 3. ResourceGroup

Concrete Azure RG produced by the AVM RG module.

| Field | Type | Source / Constraint |
|-------|------|---------------------|
| `name` | `string` | EffectiveStack.`resource_group_name`. |
| `location` | `string` | EffectiveStack.`region_full`. |
| `tags` | `map(string)` | EffectiveStack.`resource_group_tags`. |
| `id` | `string` | Output of `module.rg`. Surfaced as `resource_group_id`. |
| `enable_telemetry` | `bool` | Hard-coded `false` (research D2). |

Storage: `module "rg"` call in `modules/loganalytics/main.tf`.

### 4. Workspace

The Log Analytics workspace itself, produced by the AVM workspace module.

| Field | Type | Source / Constraint |
|-------|------|---------------------|
| `name` | `string` | EffectiveStack.`workspace_name`. |
| `location` | `string` | EffectiveStack.`region_full`. |
| `resource_group_name` | `string` | EffectiveStack.`resource_group_name`. |
| `tags` | `map(string)` | EffectiveStack.`workspace_tags`. |
| `sku` | `string` | Hard-coded `"PerGB2018"` (FR-105). |
| `retention_in_days` | `number` | `var.retention_in_days`, default `30`, range `[30, 730]` (LOG-INV-6). |
| `daily_quota_gb` | `number` | `var.daily_quota_gb`, default `-1`; valid if `== -1` OR `>= 1` (LOG-INV-7). |
| `local_authentication_disabled` | `bool` | AVM default (not overridden — FR-105). |
| `internet_ingestion_enabled` | `bool` | AVM default (not overridden — FR-105). |
| `workspace_id` (GUID) | `string` | Output of `module.workspace`; surfaced as `workspace_id`. |
| `resource_id` (ARM ID) | `string` | Output of `module.workspace`; surfaced as `workspace_resource_id`. |
| `primary_shared_key` | `string` | Output of `module.workspace`; SENSITIVE; surfaced as `primary_shared_key` (sensitive=true at every layer — research D8). |
| `enable_telemetry` | `bool` | Hard-coded `false` (research D2). |

Storage: `module "workspace"` call in `modules/loganalytics/main.tf`.

### 5. Consumer contract (published outputs)

| Output | Type | Sensitive | Notes |
|--------|------|-----------|-------|
| `workspace_id` | `string` | no | GUID (the AVM `workspace_id`, used for agent config and Kusto links). |
| `workspace_resource_id` | `string` | no | Full Azure ARM resource id; used for `log_analytics_workspace_id` on `azurerm_monitor_diagnostic_setting`. |
| `workspace_name` | `string` | no | Engine-emitted, locked by snapshot fixture per env. |
| `resource_group_name` | `string` | no | Engine-emitted: `rg-log-shd-hub-<env>-swc-001`. |
| `resource_group_id` | `string` | no | Full ARM id of the per-stack RG. |
| `primary_shared_key` | `string` | **yes** | Sensitive end-to-end; never logged. |
| `naming` | `object` | no | Passthrough of `module.naming` (gives consumers `names` / `region_full` / `engine_version`). |

See [contracts/log-stack.md](contracts/log-stack.md) for the published consumer contract.

## Invariants

| ID | Statement | Where enforced | When |
|----|-----------|----------------|------|
| LOG-INV-1 | `var.region == "swc"`. | `variable "region" { validation { … } }` in `terraform/log/variables.tf` | plan |
| LOG-INV-2 | `var.topology == "hub"`. | `variable "topology"` validation in root stack | plan |
| LOG-INV-3 | `var.tenant == "hub"`. | `variable "tenant"` validation in root stack | plan |
| LOG-INV-4 | `var.environment` is one of `["npd","prd"]`. | `variable "environment"` validation in root stack | plan |
| LOG-INV-5 | `var.subscription_id == data.azurerm_client_config.current.subscription_id`. | `check "subscription_match"` block in root stack | plan |
| LOG-INV-6 | `var.retention_in_days` integer in `[30, 730]`. | `variable "retention_in_days"` validation at BOTH root stack and wrapper | plan |
| LOG-INV-7 | `var.daily_quota_gb == -1` OR `var.daily_quota_gb >= 1`. | `variable "daily_quota_gb"` validation at BOTH root stack and wrapper | plan |
| LOG-INV-8 | Wrapper module declares no `provider` blocks (Constitution VI). | Repo review + `grep -RE '^provider ' modules/loganalytics/` in CI (already a repo lint pattern) | static |
| LOG-INV-9 | All Azure resources flow through an AVM module (Constitution IX). | Repo review + same `grep` pattern for `^resource "azurerm_` under `modules/loganalytics/`/`terraform/log/` | static |
| LOG-INV-10 | `output.primary_shared_key` is marked `sensitive = true` at wrapper AND at root stack. | `outputs.tf` declaration; `primary_shared_key_sensitive.tftest.hcl` test | plan / test |
| LOG-INV-11 | Engine emits the snapshotted `workspace_name` byte-for-byte (per env). | `positive_baseline_<env>.tftest.hcl` and `plan_snapshot_<env>.tftest.hcl` against fixtures | plan |
| LOG-INV-12 | `enable_telemetry = false` on BOTH AVM module calls (research D2). | Direct argument in `modules/loganalytics/main.tf`; static review | static |

## State transitions

Not applicable — Log Analytics workspaces are pure CRUD from Terraform's
perspective. Two state files (`hub/npd/log.tfstate`, `hub/prd/log.tfstate`)
evolve independently; there is no cross-environment Terraform dependency.

## Non-entities (explicitly out of scope)

- Application Insights component(s) — deferred (spec "Out of scope").
- `azurerm_monitor_diagnostic_setting` on the workspace itself — workspace
  is a sink in v1, not a source.
- Workspace network isolation (private link), dedicated cluster, CMK,
  resource lock, saved searches, alerts, dashboards — all deferred per
  spec "Out of scope".
- Linking producer stacks (DNS, vnet, NSG, firewall) to the workspace —
  owned by their respective feature follow-ups; this stack only PUBLISHES
  the consumer contract (entity 5).
