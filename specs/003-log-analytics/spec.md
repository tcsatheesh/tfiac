# Feature 003 — Centralized Log Analytics Workspaces

**Status**: Implemented on master alongside spec.

## Summary

Provision **two** Log Analytics Workspaces — one per hub environment —
that serve as the centralized telemetry sinks for the estate:

| Workspace | Location | Sinks logs from |
|---|---|---|
| `log-hub-npd-sdc-001` | npd-hub RG | npd, dev, pre spokes (any non-prd workload) |
| `log-hub-prd-sdc-001` | prd-hub RG | prd spokes + the prd-hub itself (incl. DNS diagnostics) |

Producer stacks (DNS zones, vnets, NSGs, firewalls, etc.) wire their
`azurerm_monitor_diagnostic_setting.X.log_analytics_workspace_id` to one
of these two workspaces via `terraform_remote_state` lookups.

## Requirements

- **FR-101**: A single `modules/loganalytics/` module handles workspace
  creation. The module is provider-less (Constitution VI).
- **FR-102**: A single generic root stack `terraform/log/` consumes the
  module. Per-deployment `(topology, tenant, environment)` is supplied
  via `variables/<env>/<scope>/log.tfvars`. Day-one deployments:
  - `(hub, hub, npd)` — via `variables/npd/hub/log.tfvars`
  - `(hub, hub, prd)` — via `variables/prd/hub/log.tfvars`
- **FR-103**: Each root stack pins its own `subscription_id`. Different
  subscriptions per environment is supported but not required day-one
  (Q9 — single subscription today).
- **FR-104**: Region is allowlisted to `swedencentral` (Q6).
- **FR-105**: Workspace SKU defaults to `PerGB2018`; retention defaults
  to `30` days. Overridable per stack via `var.retention_in_days`.
- **FR-106**: Outputs: `workspace_id`, `workspace_name`,
  `resource_group_name`. These are the only stable contract surfaces;
  consumer stacks reference them via `terraform_remote_state`.
- **FR-107**: All resources tagged with the six-key engine baseline
  (tenant, topology, environment, region, managed_by, repo).
- **FR-108**: Naming engine entry `log_analytics` (already in catalogue,
  caf_abbr=`log`, max_length=63) is the source of names. No engine
  extension required.
- **FR-109**: Subscription pinning check identical to feature 002
  (`check.subscription_pinned` in each root stack).
- **FR-110**: Deterministic — snapshot test on `workspace_name` and
  `resource_group_name` in each stack.
- **FR-111**: Legacy `modules/log/` (AVM-wrapped 90-day workspace) is
  parked under `terraform/_legacy/`. The new generic stack fully
  replaces it; a `moved.tf` stub documents the migration path.

## Out of scope (deferred)

- Wiring `azurerm_monitor_diagnostic_setting` from DNS / vnet stacks to
  the prd workspace — added in their respective feature follow-ups.
- Workspace network isolation (private link).
- Saved searches, alerts, dashboards.

## Test plan

For each deployment of the generic stack `terraform/log/` (`npd/hub`,
`prd/hub`):
1. `positive_baseline.tftest.hcl` — `terraform plan` succeeds; asserts
   `output.workspace_name == "log-hub-<env>-sdc-001"` and
   `output.resource_group_name == "rg-hub-<env>-sdc-001"`. The literal
   assertion doubles as the determinism snapshot.
2. `negative_subscription_mismatch.tftest.hcl` — `expect_failures = [check.subscription_pinned]`.
3. `negative_disallowed_region.tftest.hcl` — `expect_failures = [var.region]`.
