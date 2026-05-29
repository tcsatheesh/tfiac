# Feature 003 — Centralized Log Analytics Workspaces

**Status**: Implemented on master alongside spec.

## Summary

Provision **two** Log Analytics Workspaces — one per hub environment —
that serve as the centralized telemetry sinks for the estate. Concrete
name literals are NOT pinned here; they are emitted by the naming
engine (`hyphenated` shape, region abbr `swc` = `swedencentral`,
wrapper constants `usecase="shd"` and `stack_purpose="log"` mirroring
the DNS precedent — see Clarifications 2026-05-29). The matrix below
is illustrative:

| Workspace (engine-emitted, illustrative) | Resource group | Sinks logs from |
|---|---|---|
| `log-…-shd-hub-npd-swc-001` | `rg-log-shd-hub-npd-swc-001` | npd, dev, pre spokes (any non-prd workload) |
| `log-…-shd-hub-prd-swc-001` | `rg-log-shd-hub-prd-swc-001` | prd spokes + the prd-hub itself (incl. DNS diagnostics) |

Producer stacks (DNS zones, vnets, NSGs, firewalls, etc.) wire their
`azurerm_monitor_diagnostic_setting.X.log_analytics_workspace_id` to one
of these two workspaces via `terraform_remote_state` lookups.

## Requirements

- **FR-101**: A single `modules/loganalytics/` module handles workspace
  creation. The module is provider-less (Constitution VI).
- **FR-102**: A single generic root stack `terraform/log/` consumes the
  module. Per-deployment `(topology, tenant, environment)` is supplied
  via `variables/<tenant>/<environment>/log.tfvars.json` (Constitution VI
  scheme, precedent set by feature 002). Day-one deployments:
  - `(hub, hub, npd)` — via `variables/hub/npd/log.tfvars.json`
  - `(hub, hub, prd)` — via `variables/hub/prd/log.tfvars.json`
- **FR-103**: Each root stack pins its own `subscription_id`. Different
  subscriptions per environment is supported but not required day-one
  (Q9 — single subscription today).
- **FR-104**: Region is allowlisted to `swedencentral` (Q6).
- **FR-105**: Workspace SKU defaults to `PerGB2018`; retention defaults
  to `30` days (overridable per stack via `var.retention_in_days`);
  `daily_quota_gb = -1` (unlimited); `local_authentication_disabled`
  and `internet_ingestion_enabled` remain at AVM module defaults
  (Clarification 2026-05-29 C5).
- **FR-106**: Stable output contract consumed by other stacks via
  `terraform_remote_state` (Clarification 2026-05-29 C3):
  - `workspace_id` — GUID (`workspace_id` attribute, used in agent
    config and Kusto links)
  - `workspace_resource_id` — full ARM resource ID (used as
    `log_analytics_workspace_id` on `azurerm_monitor_diagnostic_setting`)
  - `workspace_name`
  - `resource_group_name`
  - `resource_group_id`
  - `primary_shared_key` — marked `sensitive = true`
  - `naming` — passthrough of the engine output bundle
- **FR-107**: All resources tagged with the six-key engine baseline
  (tenant, topology, environment, region, managed_by, repo).
- **FR-108**: Naming engine entry `log_analytics` (already in catalogue,
  abbr=`log`, shape=`hyphenated`, azure_max=63) is the source of names.
  Wrapper constants `usecase = "shd"` and `stack_purpose = "log"` mirror
  the DNS precedent (Clarification 2026-05-29 C2). No engine extension
  required. Region abbreviation `swc` (= `swedencentral`) per
  `modules/naming/catalogue/regions.tf` (Clarification 2026-05-29 C1 —
  `sdc` was a typo).
- **FR-109**: Subscription pinning check identical to feature 002
  (`check.subscription_pinned` in each root stack).
- **FR-110**: Deterministic — snapshot test on `workspace_name` and
  `resource_group_name` in each stack. Literal asserted in the snapshot
  test is the engine-emitted value at plan time; the spec deliberately
  does NOT pre-pin the literal (Clarification 2026-05-29 C2).
- **FR-111**: No prior `modules/log/` exists in this repo at branch
  creation (verified: `modules/` contains only `dnszones/` and
  `naming/`). Feature 003 introduces the centralized Log Analytics
  module greenfield; no `moved.tf` migration shim is required.
- **FR-112**: The wrapper module sources only the AVM module
  `Azure/avm-res-operationalinsights-workspace/azurerm`, pinned with
  `version = "~> 0.x"` (latest 0.x at implementation time) — no bare
  `azurerm_*` resources (Constitution IX). The wrapper module declares
  no provider blocks (Constitution VI). (Clarification 2026-05-29 C4)
- **FR-113**: Backend state path follows Constitution VII:
  `hub/<env>/log.tfstate` (i.e. `hub/npd/log.tfstate` and
  `hub/prd/log.tfstate`) on the shared backend storage account with
  `use_azuread_auth = true` (Clarification 2026-05-29 C5).
- **FR-114**: CI workflow `.github/workflows/log.yml` mirrors
  `.github/workflows/dns.yml`: on PRs touching `terraform/log/**` or
  `modules/loganalytics/**`, run `terraform fmt -check`,
  `terraform validate`, and `terraform test` (with `mock_provider`).
  No live-Azure calls in CI (Clarification 2026-05-29 C5).

## Out of scope (deferred)

- Wiring `azurerm_monitor_diagnostic_setting` from DNS / vnet stacks to
  the prd workspace — added in their respective feature follow-ups.
- Workspace network isolation (private link) and dedicated cluster /
  Customer-Managed Key.
- Saved searches, alerts, dashboards.
- Archive tier / long-term retention beyond the 30-day workspace
  retention (Clarification 2026-05-29 C5).
- Azure Resource Lock on the workspace or its RG — deferred to ops
  (Clarification 2026-05-29 C5).
- Diagnostic settings ON the workspace itself (the workspace is a
  *consumer* of diagnostics in v1, not a source).
- Application Insights component(s) — out of scope for feature 003;
  any AI-component work is a future feature.

## Test plan

For each deployment of the generic stack `terraform/log/` (`npd/hub`,
`prd/hub`), run under `terraform test` with `mock_provider "azurerm"`
blocks — no live-Azure calls (Clarification 2026-05-29 C5):
1. `positive_baseline.tftest.hcl` — `terraform plan` succeeds; asserts
   `output.workspace_name` and `output.resource_group_name` equal the
   engine-emitted literals for the corresponding `(topology, tenant,
   environment)` tuple. Literals are locked into the test at plan time
   and double as the determinism snapshot (FR-110).
2. `negative_subscription_mismatch.tftest.hcl` — `expect_failures = [check.subscription_pinned]`.
3. `negative_disallowed_region.tftest.hcl` — `expect_failures = [var.region]`.

## Clarifications

### Session 2026-05-29

- Q: Region short-code abbreviation for `swedencentral` (spec used `sdc`)? → A: `swc` per `modules/naming/catalogue/regions.tf`; `sdc` was a typo, corrected throughout the spec (Summary, FR-108, Test plan).
- Q: Should the spec pin the literal `log-hub-<env>-sdc-001` / `rg-hub-<env>-sdc-001` names? → A: No — the engine emits names via the `hyphenated` shape `{abbr}-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}` with wrapper constants `usecase="shd"` and `stack_purpose="log"` (DNS precedent). The exact literal is locked at plan time inside the determinism snapshot test (FR-110), not in the spec.
- Q: Is the FR-106 output contract (`workspace_id`, `workspace_name`, `resource_group_name`) sufficient for consumer stacks to wire `azurerm_monitor_diagnostic_setting`? → A: No — expanded to also expose `workspace_resource_id` (the full ARM ID needed for `log_analytics_workspace_id`), `resource_group_id`, `primary_shared_key` (sensitive), and a `naming` passthrough. FR-106 rewritten.
- Q: Which AVM module backs the wrapper, and what is the version-pinning policy? → A: `Azure/avm-res-operationalinsights-workspace/azurerm`, pinned to the latest `~> 0.x` minor. Wrapper module declares no provider blocks (Constitution VI) and uses only AVM resources (Constitution IX). Added as FR-112.
- Q: What about daily quota, backend state layout, CI workflow, and other potentially missing knobs (archive tier, resource lock, private link, App Insights)? → A: `daily_quota_gb = -1` (unlimited); `local_authentication_disabled` and `internet_ingestion_enabled` left at AVM defaults (FR-105 expanded). Backend state path `hub/<env>/log.tfstate` on the shared SA with `use_azuread_auth = true` (FR-113). CI workflow `.github/workflows/log.yml` mirrors `dns.yml` (FR-114). Archive tier, Azure Resource Lock, private link, dedicated cluster, workspace's own diagnostic settings, and Application Insights are all explicitly out of scope for v1 (Out of scope section).
