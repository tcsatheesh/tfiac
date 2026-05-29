# Phase 0 — Research: Centralized Log Analytics Workspaces (003)

This document resolves every `NEEDS CLARIFICATION` in [plan.md](plan.md)
"Technical Context", records the technology choices, and documents the
deliberate divergences from feature 002 (private DNS zones). Decisions
are numbered D1..D12 and cross-referenced from
[data-model.md](data-model.md) and [contracts/log-stack.md](contracts/log-stack.md).

## Decisions

### D1 — AVM module pins

- **Decision**: Pin `Azure/avm-res-operationalinsights-workspace/azurerm`
  with `version = "~> 0.x"` where `x` is the latest `0.x` minor at
  implementation time (the task that scaffolds the wrapper will record
  the exact minor — e.g. `~> 0.4` if `0.4.0` is current). Pin
  `Azure/avm-res-resources-resourcegroup/azurerm` `~> 0.4` (same pin as
  feature 002 for consistency).
- **Rationale**: Both AVM modules are pre-1.0; caret-minor pin (per spec
  Clarification 2026-05-29 C4) lets security/bug patches in while
  requiring a deliberate PR for minor/major bumps. Matches feature 002's
  D1 reasoning and the Principle IX direction in the constitution sync
  impact report (v2.2.0).
- **Alternatives considered**: Exact pin (`= 0.x.y`) — rejected: any AVM
  patch requires a manual bump, slowing security fixes. Floating major
  (`>= 0.x`) — rejected: pre-1.0 minors are explicitly allowed to break.

### D2 — Telemetry: explicit `enable_telemetry = false` (DIVERGENCE from feature 002)

- **Decision**: Set `enable_telemetry = false` on BOTH AVM module
  instantiations (workspace and RG).
- **Rationale**: Per the originating user directive for this feature.
  Hub-level observability stacks deliberately avoid emitting their own
  `modtm_telemetry` resources to keep the apply diff minimal and to
  remove an outbound HTTP dependency from the bootstrap path.
- **Spec alignment**: Not contradicted by the spec; the spec leaves
  module-level switches to the plan. Documented here so a future feature
  bringing telemetry back is an explicit, reviewed change.
- **Alternatives considered**: Leave at AVM default (`true`, as feature
  002 does) — rejected per user directive. A wrapper-level boolean
  override (`var.enable_telemetry`) — rejected: per Constitution II
  ("intent only"), telemetry-on is not an intent the consumer expresses.

### D3 — AVM-required providers

- **Decision**: Both AVM modules transitively require `azure/azapi
  ~> 2.4`, `azure/modtm ~> 0.3`, `hashicorp/random ~> 3.5`. The
  workspace module additionally pulls `hashicorp/time ~> 0.13` for its
  internal retention bookkeeping. Pin all four in
  `terraform/log/versions.tf` once (Principle VII). The wrapper module's
  `providers.tf` only re-declares `required_providers` (no provider
  blocks — Constitution VI).
- **Rationale**: Identical pattern to feature 002 D2. `modtm` is still
  declared even though `enable_telemetry = false` because the AVM modules
  reference the provider unconditionally in their `versions.tf` — it
  must be installable; it just won't be exercised at plan/apply time.
- **Alternatives considered**: Letting Terraform resolve transitively —
  rejected (Principle VII). Removing `modtm` from `required_providers`
  — rejected: would fail `terraform init` against the AVM module.

### D4 — Two environments → ONE source tree, TWO state keys (backend-key parameterization)

- **Decision**: `terraform/log/backend.tf` declares the `azurerm` backend
  block WITHOUT a `key`. At init time the operator passes
  `-backend-config="key=hub/${env}/log.tfstate"` (and the
  resource-group/storage-account/container values, as feature 002 already
  does). The same source tree is `terraform init`-ed twice into two
  separate `.terraform/` workspaces (operators are expected to keep
  per-env worktrees, OR to wipe `.terraform/` between inits — both
  approaches are documented in [quickstart.md](quickstart.md)).
- **Rationale**: Backend blocks cannot interpolate variables, so the
  `key` field cannot be templated in code. The two real options were
  (a) per-env `backend.<env>.hcl` partial-config files committed to the
  repo, or (b) a fully runtime-supplied `key`. We chose (b) because:
  (i) the `key` already follows a documented Constitution VII path scheme
  (`<tenant>/<env>/<purpose>.tfstate`), so each operator can derive it
  mechanically — no per-env file proliferation; (ii) it matches the
  existing repo pattern where `resource_group_name`, `storage_account_name`,
  `container_name` are ALREADY supplied at init time (feature 002 D12);
  (iii) it keeps the day-one CI matrix simple (one `init` step per matrix
  entry, with `key` interpolated from `matrix.env`).
- **Spec impact**: FR-113 (state path) is satisfied without per-env code
  branching. Recorded in [data-model.md](data-model.md) under "EffectiveStack".
- **Alternatives considered**:
  1. `backend.npd.hcl` + `backend.prd.hcl` partial-config files —
     rejected: introduces two committed files whose only difference is
     the `key` line, inviting drift.
  2. Two root-stack directories (`terraform/log-npd/`, `terraform/log-prd/`)
     — rejected: violates the user directive ("Root stack accepts
     `environment` validated to `npd` OR `prd`"); doubles code surface;
     guarantees drift over time.
  3. Terraform workspaces (`terraform workspace new <env>`) — rejected:
     Constitution VII's state-path scheme (`<tenant>/<env>/<purpose>.tfstate`)
     does NOT map to `env:/` workspace keys; using workspaces would force
     a non-conformant state path.

### D5 — Naming-engine wiring: existing `log_analytics` slot, `service_purpose = "shd"`

- **Decision**: Use the engine's `log_analytics` service-type slot
  AS-IS (verified in
  [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf#L30):
  `abbr = "log"`, `shape = "hyphenated"`, `azure_max = 63`, `level = "top"`).
  At the wrapper, the workspace entry is fed to the engine with:
  - `service_type = "log_analytics"`
  - `key = var.workspace_key` (default `"central"` — internal map key, not
    the canonical Azure name)
  - `service_purpose = "shd"` (matches `usecase = "shd"` for the shared
    aggregation workspace; the engine REQUIRES a non-null `service_purpose`
    for non-RG non-FQDN hyphenated entries per INV-4)
  - `stack_purpose` is left null on this entry (the engine picks it up
    from `var.input.stack_purpose = "log"` for the RG entry's
    `rg_hyphenated` shape).
- **Engine output literal (locked by the snapshot test at impl time)**:
  - RG: `rg-log-shd-hub-<env>-swc-001` (matches the user-supplied
    canonical in the originating directive).
  - Workspace: derived from the engine's `hyphenated` template
    `{abbr}-{service_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}`
    → expected `log-shd-shd-hub-<env>-swc-001`. The double `shd` is a
    cosmetic consequence of the engine treating `service_purpose` and
    `usecase` as orthogonal axes; it is NOT pinned in the spec — the
    snapshot fixture locks whatever the engine emits at the
    implementation commit.
- **Rationale**: Matches feature 002's "use the engine as-is" approach
  (002 D3). No engine PR required. `shd` is the documented house value
  for shared/centralised infrastructure (consistent with `usecase`).
- **Alternatives considered**:
  1. `service_purpose = "central"` or `"tel"` — rejected: introduces a
     new house abbreviation not present anywhere else in the repo today;
     `shd` is already the project-wide shared marker.
  2. Modify the engine to accept null `service_purpose` for `log_analytics`
     entries — rejected: out of scope; would be a feature-001 patch and
     re-opens INV-4 invariant.
  3. Leave `service_purpose` null and let the engine substitute `"x"` —
     rejected: INV-4 would fire and fail plan with a misleading message;
     the spec wants a hard-fail on real violations, not on engine
     bookkeeping gaps.

### D6 — Per-stack RG via AVM resource-group module

- **Decision**: `module "rg" { source = "Azure/avm-res-resources-resourcegroup/azurerm"; version = "~> 0.4"; name = module.naming.names[<rg_key>].name; location = local.region_full; tags = module.naming.names[<rg_key>].tags; enable_telemetry = false }`.
- **Rationale**: Constitution IX. The engine emits `rg-log-shd-hub-<env>-swc-001`
  per FR-108 + D5. Tag-wiring satisfies FR-107 + Principle VIII.
- **Alternatives considered**: Hand-rolled `azurerm_resource_group` —
  forbidden by Principle IX since an AVM exists.

### D7 — Hard-fails fire via `variable.validation` blocks (and one `check`)

- **Decision**: The plan-time hard-fails the user listed as cross-cutting
  are implemented as follows:
  - `topology == "hub"` → `variable "topology" { validation { condition = var.topology == "hub" } }` at the root stack.
  - `tenant == "hub"` → `variable "tenant" { validation { condition = var.tenant == "hub" } }` at the root stack.
  - `region == "swc"` → `variable "region" { validation { condition = var.region == "swc" } }` at the root stack.
  - `environment ∈ {"npd","prd"}` → `variable "environment" { validation { condition = contains(["npd","prd"], var.environment) } }` at the root stack.
  - `subscription_id == data.azurerm_client_config.current.subscription_id`
    → `check "subscription_match" { assert { condition = ... } }` at the
    root stack (FR-029-equivalent / FR-109).
  - `retention_in_days ∈ [30, 730]` → `variable "retention_in_days" { validation { condition = var.retention_in_days >= 30 && var.retention_in_days <= 730 } }` at the root stack AND the wrapper module.
  - `daily_quota_gb == -1 || daily_quota_gb >= 1` →
    `variable "daily_quota_gb" { validation { condition = var.daily_quota_gb == -1 || var.daily_quota_gb >= 1 } }` at the root stack AND the wrapper module.
- **Rationale**: All checks fire at `terraform plan` time with clear,
  message-rich operator-facing errors. Mirrors feature 002's D8 pattern;
  the `check {}` block was already proven correct in feature 002.
- **Alternatives considered**: A single `terraform_data "assertions"`
  with aggregated preconditions — rejected: individual `validation`
  blocks give better per-input error messages (the AVM modules surface
  the variable name in the failure summary). Apply-time `null_resource`
  — forbidden by Constitution IV.

### D8 — Output contract & sensitivity propagation

- **Decision**: The wrapper module exposes:

  | Output | Type | Sensitive | Source |
  |---|---|---|---|
  | `workspace_id` | `string` | no | AVM `workspace_id` (GUID) |
  | `workspace_resource_id` | `string` | no | AVM `resource_id` |
  | `workspace_name` | `string` | no | `module.naming.names[<workspace_key>].name` |
  | `resource_group_name` | `string` | no | `module.naming.names[<rg_key>].name` |
  | `resource_group_id` | `string` | no | `module.rg.resource_id` |
  | `primary_shared_key` | `string` | **yes** | AVM `primary_shared_key` |
  | `naming` | `object` | no | passthrough of `module.naming` |

  The root stack re-exports every field 1:1, preserving the `sensitive`
  flag on `primary_shared_key` (Terraform propagates `sensitive` through
  output chaining when the source attribute is itself sensitive; we
  ALSO declare `sensitive = true` explicitly on the root output for
  defence-in-depth and `terraform output -json` legibility).
- **Rationale**: Direct implementation of spec Clarification C3. The
  GUID (`workspace_id`) goes to agent/Kusto links; the ARM resource ID
  (`workspace_resource_id`) goes to `azurerm_monitor_diagnostic_setting.log_analytics_workspace_id`;
  the `primary_shared_key` is needed by legacy direct-write clients but
  MUST never appear in plan output / CI logs.
- **Alternatives considered**: Expose only `workspace_resource_id` and
  derive the GUID consumer-side — rejected: forces every consumer to
  parse the ARM ID, defeats the purpose of a contract. Skip
  `primary_shared_key` entirely (force consumers to read it via
  `data.azurerm_log_analytics_workspace`) — rejected: makes the
  diagnostic-settings + agent install path noticeably more verbose.

### D9 — Snapshot fixtures: per-environment

- **Decision**: Commit per-env snapshot JSON fixtures under
  `modules/loganalytics/tests/fixtures/`:
  - `workspace_name_snapshot_npd.json` — single string literal
    (engine-emitted workspace name for the npd-hub apply).
  - `workspace_name_snapshot_prd.json` — same, for prd-hub.
  - `resource_group_name_snapshot.json` — env-templated; the test reads
    it and substitutes `<env>` before comparing.
  The two `positive_baseline_<env>.tftest.hcl` files load the
  corresponding fixture and assert byte-equality against
  `output.workspace_name`. Stack-level `plan_snapshot_<env>.tftest.hcl`
  tests do the same after the engine-wrapper composition.
- **Rationale**: Two environments mean two distinct literal names; one
  shared fixture would mask drift between them. JSON (not raw text) is
  used so future contract additions can extend the snapshot without
  retooling the test harness.
- **Alternatives considered**: One combined `snapshot.json` keyed by env
  — rejected: tests against a single env can't run in isolation;
  per-env files match the per-env tfvars + per-env state key pattern
  used everywhere else in the stack.

### D10 — Test framework: native `terraform test` with mocked providers

- **Decision**: Mirror feature 001 / 002 exactly. `*.tftest.hcl` files
  with `mock_provider "azurerm" {}`, `mock_provider "azapi" {}`,
  `mock_provider "modtm" {}`, `mock_provider "random" {}`,
  `mock_provider "time" {}` defined once in `_fixtures.tftest.hcl` and
  inherited by every other test file in the directory. No live-Azure
  calls in CI (FR-114 + spec Clarification C5).
- **Rationale**: Established repo practice; zero new tooling.

### D11 — Negative tests enumerated

- **Decision**: The plan files the following negative tests under
  `terraform/log/tests/`:
  - `wrong_topology.tftest.hcl` — `expect_failures = [var.topology]`
  - `wrong_tenant.tftest.hcl` — `expect_failures = [var.tenant]`
  - `wrong_region.tftest.hcl` — `expect_failures = [var.region]`
  - `wrong_environment.tftest.hcl` — `expect_failures = [var.environment]`
  - `subscription_mismatch.tftest.hcl` — `expect_failures = [check.subscription_match]`
  
  And under `modules/loganalytics/tests/`:
  - `retention_below_range.tftest.hcl` — `expect_failures = [var.retention_in_days]` (input `29`)
  - `retention_above_range.tftest.hcl` — `expect_failures = [var.retention_in_days]` (input `731`)
  - `quota_invalid.tftest.hcl` — `expect_failures = [var.daily_quota_gb]` (input `0`)
  - `primary_shared_key_sensitive.tftest.hcl` — `expect_failures = []`; asserts that the output is marked `sensitive` (via `output.primary_shared_key` reference in an assertion that uses `sensitive(...)` wrapping).
- **Rationale**: One test per FR. Each test exercises one and only one
  failure path so CI output points at the offending input directly. Mirrors
  feature 002's negative-test discipline.

### D12 — CI workflow: `.github/workflows/log.yml` mirrors `dns.yml` with a matrix entry per directory

- **Decision**: Copy `.github/workflows/dns.yml` to `.github/workflows/log.yml`
  with the following substitutions:
  - `name: log`
  - paths: `modules/loganalytics/**`, `terraform/log/**`,
    `variables/hub/npd/log.tfvars.json`, `variables/hub/prd/log.tfvars.json`,
    `.github/workflows/log.yml`
  - matrix `dir:` `[modules/loganalytics, terraform/log]`
  - Terraform version: `1.9.8` (same as feature 002).
  - Steps: `fmt -check -recursive`, `init -backend=false`, `validate`,
    `test`. No live-Azure auth.
- **Rationale**: Identical structure to feature 002 minimises operator
  surprise. Per-env tfvars files are watched (not consumed by `test`,
  which uses `mock_provider`) so a tfvars typo PR triggers the workflow
  even if no `.tf` file changed.
- **Alternatives considered**: A unified `infra.yml` matrixed over
  modules — rejected: tightly couples unrelated changes; a DNS-only PR
  shouldn't re-run log-analytics tests, and vice versa.

## Resolved unknowns

The plan's Technical Context block has zero remaining `NEEDS CLARIFICATION`
markers. Every dependency, version, and pattern is now grounded in either a
published AVM version, the existing repo engine source, the spec's
2026-05-29 clarification session, or an explicit precedent from feature 002.
