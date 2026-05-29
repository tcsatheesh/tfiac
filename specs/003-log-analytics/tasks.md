# Tasks: Centralized Log Analytics Workspaces (npd-hub + prd-hub)

**Input**: Design documents from `/specs/003-log-analytics/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/log-stack.md, quickstart.md

**Tests**: INCLUDED. FR-110, FR-114, and the Test plan in spec.md explicitly mandate `terraform test`-based plan-time assertions and committed snapshot fixtures (per env), so test tasks are first-class.

**Two-environment delivery**: ONE wrapper module (`modules/loganalytics/`) + ONE root stack (`terraform/log/`) deployed TWICE — once per env (`npd`, `prd`). The wrapper is env-agnostic; the root stack hard-pins `topology=hub`, `tenant=hub`, `region=swc` and accepts `environment ∈ {npd, prd}` (research D4, D7). Per-env tfvars + per-env state keys (`hub/npd/log.tfstate`, `hub/prd/log.tfstate`).

**Reference shape**: Mirrors [specs/002-private-dns-zones/tasks.md](../002-private-dns-zones/tasks.md).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete dependencies)
- **[Story]**: US1 / US2 / US3 — maps to a spec.md user story (or [Setup] / [Foundational] / [Polish])
- All paths are repository-relative; absolute paths used in command bodies

## Path Conventions

- Wrapper module: `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/`
- Root stack: `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`
- Stack inputs (npd): `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/variables/hub/npd/log.tfvars.json`
- Stack inputs (prd): `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/variables/hub/prd/log.tfvars.json`
- CI workflow: `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/.github/workflows/log.yml`
- Naming engine (already on master, NOT modified): `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/naming/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Skeleton directories, version pins, backend wiring, provider passthrough so every subsequent task has a place to land.

- [X] T001 [Setup] Create directory skeletons: `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/`, `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/`, `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/fixtures/`, `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`, `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/`, `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/variables/hub/npd/`, `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/variables/hub/prd/`
- [X] T002 [P] [Setup] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/versions.tf` pinning `terraform "~> 1.9"`, `azurerm "~> 4.0"`, `azapi "~> 2.4"`, `modtm "~> 0.3"`, `random "~> 3.5"`, `time "~> 0.13"` (research D3, Constitution VII)
- [X] T003 [P] [Setup] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/backend.tf` declaring `backend "azurerm"` WITHOUT a `key` field; `key` injected at init via `-backend-config="key=hub/<env>/log.tfstate"` (research D4, FR-113, Constitution VII). Set `use_azuread_auth = true`.
- [X] T004 [P] [Setup] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/providers.tf` with `provider "azurerm" { subscription_id = var.subscription_id; features {} }`
- [X] T005 [P] [Setup] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/providers.tf` declaring `required_providers` passthrough (`azurerm`, `azapi`, `modtm`, `random`, `time`) — NO `provider` blocks (Constitution VI, LOG-INV-8)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Wrapper module skeleton + naming-engine plumbing + AVM RG module + root-stack scope hard-fails + reference tfvars (both envs). EVERY user story depends on these existing before its tasks can start.

**CRITICAL**: Do not begin Phase 3 until Phase 2 is complete and T019 gate passes.

- [X] T006 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/variables.tf` with inputs `var.input` (engine input bundle object), `var.workspace_key` (default `"central"`), `var.retention_in_days` (default `30`) with `validation` enforcing `>= 30 && <= 730` (LOG-INV-6), `var.daily_quota_gb` (default `-1`) with `validation` enforcing `== -1 || >= 1` (LOG-INV-7) — messages MUST name the offending value (research D7)
- [X] T007 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/locals.tf` deriving the engine `services` list (entry 0: `service_type="log_analytics"`, `key=var.workspace_key`, `service_purpose="shd"`; entry 1: `service_type="resource_group"`, `key="main"`) and exposing `local.region_full` from the engine output (research D5, data-model Entity 1)
- [X] T008 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/main.tf` instantiating `module "naming" { source = "../naming"; input = var.input; services = local.services }` (research D5; engine consumed as-is, no extension)
- [X] T009 [Foundational] Extend `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/main.tf` with `module "rg" { source = "Azure/avm-res-resources-resourcegroup/azurerm"; version = "~> 0.4"; name = module.naming.names[<rg_key>].name; location = local.region_full; tags = module.naming.names[<rg_key>].tags; enable_telemetry = false }` (research D6, LOG-INV-12, FR-107, Constitution IX)
- [X] T010 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/check.tf` with a `terraform_data "assertions"` resource carrying preconditions that the engine produced both `<workspace_key>` and `<rg_key>` entries in `module.naming.names`, and an output-level precondition for LOG-INV-10 in T012 (research D7/D8)
- [X] T011 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/outputs.tf` declaring `workspace_id`, `workspace_resource_id`, `workspace_name`, `resource_group_name`, `resource_group_id`, `primary_shared_key` (with `sensitive = true` — LOG-INV-10, FR-106), `naming` (passthrough) — sources initially placeholder until T024 wires the workspace module (data-model Entity 5)
- [X] T012 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/variables.tf` with inputs `subscription_id`, `region`, `repo`, `topology`, `tenant`, `environment`, `retention_in_days` (default 30), `daily_quota_gb` (default -1), `workspace_key` (default "central"). `variable.validation` blocks: `topology == "hub"` (LOG-INV-2), `tenant == "hub"` (LOG-INV-3), `region == "swc"` (LOG-INV-1), `contains(["npd","prd"], var.environment)` (LOG-INV-4), `retention_in_days` range (LOG-INV-6), `daily_quota_gb` rule (LOG-INV-7) — all messages name the offending value (research D7, contracts/log-stack.md hard-fail catalogue)
- [X] T013 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/locals.tf` shaping the wrapper-module input object from `var.*`, injecting `usecase = "shd"`, `stack_purpose = "log"`, `managed_by = "terraform"` (research D5, data-model Entity 1)
- [X] T014 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/main.tf` calling `module "loganalytics" { source = "../../modules/loganalytics"; input = local.naming_input; retention_in_days = var.retention_in_days; daily_quota_gb = var.daily_quota_gb; workspace_key = var.workspace_key }` AND adding `check "subscription_match" { assert { condition = var.subscription_id == data.azurerm_client_config.current.subscription_id; error_message = "..." } }` (LOG-INV-5, FR-109, research D7). Add the corresponding `data "azurerm_client_config" "current" {}`.
- [X] T015 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/outputs.tf` re-exporting `workspace_id`, `workspace_resource_id`, `workspace_name`, `resource_group_name`, `resource_group_id`, `primary_shared_key` (with explicit `sensitive = true` — LOG-INV-10, defence-in-depth per research D8), `naming` from the wrapper module (contracts/log-stack.md)
- [X] T016 [P] [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/variables/hub/npd/log.tfvars.json` with reference inputs from quickstart §1 (placeholder `subscription_id`, `region=swc`, `topology=hub`, `tenant=hub`, `environment=npd`, `retention_in_days=30`, `daily_quota_gb=-1`)
- [X] T017 [P] [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/variables/hub/prd/log.tfvars.json` with reference inputs from quickstart §1 (placeholder `subscription_id`, `region=swc`, `topology=hub`, `tenant=hub`, `environment=prd`, `retention_in_days=30`, `daily_quota_gb=-1`)
- [X] T018 [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/_fixtures.tftest.hcl` declaring `mock_provider "azurerm" {}`, `mock_provider "azapi" {}`, `mock_provider "modtm" {}`, `mock_provider "random" {}`, `mock_provider "time" {}` and a reusable `variables` block with the reference engine input (research D10)
- [X] T019 [P] [Foundational] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/_fixtures.tftest.hcl` declaring the same five `mock_provider` blocks plus a reusable `variables` block carrying the npd reference tfvars baseline (research D10)
- [X] T020 [Foundational] Run `terraform init -backend=false && terraform validate` in BOTH `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/` AND `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/` and confirm bare skeleton compiles (gate before Phase 3)

**Checkpoint**: Wrapper compiles, root stack compiles, naming engine wired, AVM RG instantiated, all SIX cross-cutting hard-fails (topology/tenant/region/environment/subscription/retention+quota) fire — user stories can now begin.

---

## Phase 3: User Story 1 — Workspace deploys deterministically per env (Priority: P1) 🎯 MVP

**Goal**: A consumer reads `terraform_remote_state.log_<env>.outputs.workspace_id` / `workspace_resource_id` / `workspace_name` / `primary_shared_key` and gets the published contract; engine-emitted names are byte-stable per env; re-plan with unchanged inputs is zero-diff.

**Independent Test**: From a clean state apply with reference inputs for either env → `output.workspace_name` equals the engine-emitted literal locked in the per-env snapshot fixture; `output.workspace_resource_id` is non-empty; `output.primary_shared_key` is marked sensitive; re-plan → 0/0/0 (spec Test plan #1, FR-110, FR-106, LOG-INV-11, LOG-INV-10).

### Tests for User Story 1 (write BEFORE implementation — TDD)

- [X] T021 [P] [US1] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/positive_baseline_npd.tftest.hcl` — with npd reference inputs, asserts `output.workspace_name == file("tests/fixtures/workspace_name_snapshot_npd.json")` (after `jsondecode`) and `output.resource_group_name` equals the env-substituted snapshot (FR-110, LOG-INV-11, research D9). `expect_failures = []`.
- [X] T022 [P] [US1] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/positive_baseline_prd.tftest.hcl` — same as T021 but with prd reference inputs and the `_prd` snapshot fixture (FR-110, LOG-INV-11, research D9). `expect_failures = []`.
- [X] T023 [P] [US1] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/primary_shared_key_sensitive.tftest.hcl` asserting `output.primary_shared_key` is marked sensitive (LOG-INV-10, FR-106, research D11). `expect_failures = []`.
- [X] T024 [P] [US1] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/plan_zero_diff_npd.tftest.hcl` running plan twice with npd reference inputs and asserting the second plan is zero-diff (FR-110, spec Test plan #1). `expect_failures = []`.
- [X] T025 [P] [US1] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/plan_zero_diff_prd.tftest.hcl` running plan twice with prd reference inputs and asserting zero-diff (FR-110). `expect_failures = []`.

### Implementation for User Story 1

- [X] T026 [US1] Extend `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/main.tf` with `module "workspace" { source = "Azure/avm-res-operationalinsights-workspace/azurerm"; version = "~> 0.x" (latest 0.x at impl time); name = module.naming.names[<workspace_key>].name; location = local.region_full; resource_group_name = module.rg.name; tags = module.naming.names[<workspace_key>].tags; log_analytics_workspace_sku = "PerGB2018"; log_analytics_workspace_retention_in_days = var.retention_in_days; log_analytics_workspace_daily_quota_gb = var.daily_quota_gb; enable_telemetry = false }` (FR-105, FR-112, LOG-INV-12, research D1/D2, Constitution IX)
- [X] T027 [US1] Wire `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/outputs.tf` final sources: `workspace_id = module.workspace.workspace_id`, `workspace_resource_id = module.workspace.resource_id`, `workspace_name = module.naming.names[<workspace_key>].name`, `resource_group_name = module.naming.names[<rg_key>].name`, `resource_group_id = module.rg.resource_id`, `primary_shared_key = module.workspace.primary_shared_key` (sensitive), `naming = module.naming` (FR-106, research D8, data-model Entity 5)
- [X] T028 [P] [US1] Capture npd reference snapshot: in `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`, run `terraform plan -out=ref.npd -var-file=../../variables/hub/npd/log.tfvars.json` then `terraform show -json ref.npd | jq '.planned_values.outputs.workspace_name.value'` and commit the JSON value to `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/fixtures/workspace_name_snapshot_npd.json` (research D9, quickstart §9, FR-110)
- [X] T029 [P] [US1] Capture prd reference snapshot: same procedure as T028 with `variables/hub/prd/log.tfvars.json` → `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/fixtures/workspace_name_snapshot_prd.json` (research D9, quickstart §9, FR-110)
- [X] T030 [P] [US1] Capture env-templated RG snapshot at `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/fixtures/resource_group_name_snapshot.json` (single string with `<env>` placeholder; test substitutes before comparing — research D9)
- [X] T031 [P] [US1] Document the snapshot regeneration procedure in `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/fixtures/README.md` (verbatim commands from quickstart §9 for both envs)
- [X] T032 [US1] Run `terraform test` in both `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/` and `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`; confirm T021–T025 pass

**Checkpoint**: US1 is fully functional — workspace deploys, consumer contract holds, both envs have deterministic snapshots.

---

## Phase 4: User Story 2 — Both environments deploy independently (Priority: P1)

**Goal**: The same root-stack source tree can be `terraform init` + `apply`-ed against either `hub/npd/log.tfstate` or `hub/prd/log.tfstate` with the appropriate tfvars file; an environment value outside `{npd, prd}` hard-fails at plan time; scope hard-pins (topology/tenant/region) reject anything else.

**Independent Test**: With npd tfvars + npd state key, plan succeeds; with prd tfvars + prd state key, plan succeeds; with `environment="dev"` plan fails on `var.environment`; with `topology="spoke"` plan fails on `var.topology` (research D4, D7, D11; FR-102, FR-104, LOG-INV-1..4).

### Tests for User Story 2 (write BEFORE implementation — TDD)

- [X] T033 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/wrong_environment.tftest.hcl` with `expect_failures = [var.environment]` for `environment = "dev"` (LOG-INV-4, research D11; contracts/log-stack.md hard-fail catalogue)
- [X] T034 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/wrong_topology.tftest.hcl` with `expect_failures = [var.topology]` for `topology = "spoke"` (LOG-INV-2, FR-102)
- [X] T035 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/wrong_tenant.tftest.hcl` with `expect_failures = [var.tenant]` for `tenant = "spoke"` (LOG-INV-3)
- [X] T036 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/wrong_region.tftest.hcl` with `expect_failures = [var.region]` for `region = "neu"` (LOG-INV-1, FR-104; spec Test plan #3)
- [X] T037 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/subscription_mismatch.tftest.hcl` with `expect_failures = [check.subscription_match]` for `subscription_id = "11111111-1111-1111-1111-111111111111"` (LOG-INV-5, FR-109; spec Test plan #2)
- [X] T038 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/plan_snapshot_npd.tftest.hcl` — root-stack-level test running plan with npd tfvars and asserting `output.workspace_name` matches the npd snapshot fixture byte-for-byte (FR-110, LOG-INV-11)
- [X] T039 [P] [US2] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/plan_snapshot_prd.tftest.hcl` — same as T038 with prd tfvars and prd fixture (FR-110, LOG-INV-11)

### Implementation for User Story 2

- [X] T040 [US2] Confirm the `variable "environment"` validation in `terraform/log/variables.tf` (from T012) uses `contains(["npd","prd"], var.environment)`; tighten the error message to name the offending value (research D7, contracts/log-stack.md)
- [X] T041 [US2] Confirm `terraform/log/backend.tf` (from T003) carries NO `key` field so `-backend-config="key=hub/<env>/log.tfstate"` at init time selects the per-env state (research D4, FR-113)
- [X] T042 [US2] Run `terraform test` in `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/` and confirm T033–T039 pass

**Checkpoint**: US2 works — both environments can deploy independently from one source tree; all scope hard-fails fire at plan time.

---

## Phase 5: User Story 3 — Retention and daily-quota knobs are validated (Priority: P2)

**Goal**: `retention_in_days` outside `[30, 730]` and `daily_quota_gb` not in `{-1} ∪ [1, ∞)` hard-fail at plan time at BOTH the root stack and the wrapper module (defence-in-depth per research D7).

**Independent Test**: `retention_in_days = 29` → plan fails on `var.retention_in_days`; `retention_in_days = 731` → plan fails; `daily_quota_gb = 0` → plan fails on `var.daily_quota_gb`; `daily_quota_gb = -2` → plan fails (FR-105, LOG-INV-6, LOG-INV-7).

### Tests for User Story 3 (write BEFORE implementation — TDD)

- [X] T043 [P] [US3] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/retention_below_range.tftest.hcl` with `expect_failures = [var.retention_in_days]` for `retention_in_days = 29` (LOG-INV-6, FR-105, research D11)
- [X] T044 [P] [US3] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/retention_above_range.tftest.hcl` with `expect_failures = [var.retention_in_days]` for `retention_in_days = 731` (LOG-INV-6, FR-105)
- [X] T045 [P] [US3] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/quota_zero_invalid.tftest.hcl` with `expect_failures = [var.daily_quota_gb]` for `daily_quota_gb = 0` (LOG-INV-7, FR-105, research D11)
- [X] T046 [P] [US3] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/tests/quota_negative_invalid.tftest.hcl` with `expect_failures = [var.daily_quota_gb]` for `daily_quota_gb = -2` (LOG-INV-7, FR-105)
- [X] T047 [P] [US3] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/retention_out_of_range.tftest.hcl` with `expect_failures = [var.retention_in_days]` for `retention_in_days = 0` (LOG-INV-6 root-stack copy; defence-in-depth per research D7)
- [X] T048 [P] [US3] Write `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/tests/quota_invalid.tftest.hcl` with `expect_failures = [var.daily_quota_gb]` for `daily_quota_gb = 0` (LOG-INV-7 root-stack copy)

### Implementation for User Story 3

- [X] T049 [US3] Confirm the `var.retention_in_days` and `var.daily_quota_gb` validation blocks exist in BOTH `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/variables.tf` (from T006) AND `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/variables.tf` (from T012). Tighten error messages to name the offending value and the allowed range/rule (research D7, contracts/log-stack.md hard-fail catalogue).
- [X] T050 [US3] Run `terraform test` in both `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/` and `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`; confirm T043–T048 pass

**Checkpoint**: US3 works — observability knobs are bounded and hard-fail with clear messages at both layers.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: READMEs, CI workflow, SC grep audit, final fmt/test gates.

- [X] T051 [P] [Polish] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/README.md` documenting inputs, outputs, hard-fails (LOG-INV-1..12), the AVM workspace + RG dependency pins, the snapshot fixture pair (npd + prd), and the `enable_telemetry = false` divergence from feature 002 (Constitution VI, research D2)
- [X] T052 [P] [Polish] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/README.md` with the quickstart.md §3 + §4 operator commands inlined verbatim (init/plan/apply for BOTH envs, backend-config snippets including per-env `key`, RBAC, `.env` pattern, consumer usage from quickstart §5)
- [X] T053 [P] [Polish] Create `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/.github/workflows/log.yml` mirroring `.github/workflows/dns.yml` with substitutions per research D12: `name: log`; trigger paths `modules/loganalytics/**`, `terraform/log/**`, `variables/hub/npd/log.tfvars.json`, `variables/hub/prd/log.tfvars.json`, `.github/workflows/log.yml`; matrix `dir: [modules/loganalytics, terraform/log]`; steps `fmt -check -recursive`, `init -backend=false`, `validate`, `test`. No live-Azure auth (FR-114, spec Clarification C5)
- [X] T054 [Polish] Grep audit (SC-008-equivalent): `grep -rE "(log-shd|rg-log-shd|privatelink|workspace_id\s*=\s*\")" /home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/*.tf /home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/*.tf` MUST return zero matches outside snapshot fixtures (no hand-built names; engine is the single source — Constitution III)
- [X] T055 [Polish] Final pass: run `terraform fmt -recursive /home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/ /home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`, then `terraform test` in BOTH `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/modules/loganalytics/` AND `/home/satheesh/projects/www.github.com/tcsatheesh/tfiac/terraform/log/`, then verify against [contracts/log-stack.md](contracts/log-stack.md) Outputs and Compatibility tables that the published output surface matches exactly (`workspace_id`, `workspace_resource_id`, `workspace_name`, `resource_group_name`, `resource_group_id`, `primary_shared_key` sensitive, `naming`). Mark every checkbox above `[X]` once green.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately.
- **Foundational (Phase 2)**: depends on Phase 1; BLOCKS all user stories. Gated by T020 (`init -backend=false && validate` passes in both directories).
- **User Story 1 (Phase 3)**: depends only on Phase 2. MVP. Gated by T032 (all US1 tests green).
- **User Story 2 (Phase 4)**: depends on Phase 2 + the workspace module from T026 (so plan-snapshot tests can exercise the full composition). Gated by T042.
- **User Story 3 (Phase 5)**: depends only on Phase 2 (validation blocks already exist at the variable layer). Gated by T050.
- **Polish (Phase 6)**: depends on all user stories so the README + CI workflow reflect the final shape.

### Within Each User Story

- Tests are written FIRST (T021–T025, T033–T039, T043–T048) and MUST FAIL before implementation begins for that story (TDD).
- Snapshot fixtures (T028–T031) are captured AFTER the workspace module wires up (T026/T027) and BEFORE the gate run (T032), since the tests in T021/T022/T038/T039 reference them.
- Implementation before re-running tests for the green check.

### Checkpoint Gates (must pass before next phase begins)

| Gate | Verifies | Command |
|------|----------|---------|
| **T020** | Phase 2 → Phase 3 | `terraform init -backend=false && terraform validate` in both dirs |
| **T032** | Phase 3 → Phase 4 | `terraform test` green for T021–T025 |
| **T042** | Phase 4 → Phase 5 | `terraform test` green for T033–T039 |
| **T050** | Phase 5 → Phase 6 | `terraform test` green for T043–T048 |
| **T055** | Final | `fmt` clean + `test` green in both dirs + output surface matches contracts/log-stack.md |

### Parallel Opportunities

- **Phase 1**: T002, T003, T004, T005 are independent files → all `[P]`.
- **Phase 2**: T016, T017, T019 are independent of the wrapper-module file sequence and may run in parallel with T006–T015. T020 is the sequential gate.
- **Phase 3 tests**: T021–T025 each touch a distinct file → all `[P]`. T028–T031 each touch a distinct fixture file → all `[P]`.
- **Phase 4 tests**: T033–T039 each touch a distinct file → all `[P]`.
- **Phase 5 tests**: T043–T048 each touch a distinct file → all `[P]`.
- **Phase 6**: T051, T052, T053 are independent files → all `[P]`. T054 and T055 run sequentially as final gates.
- **Cross-phase**: Once Phase 2 completes, US1, US2 (test files only — implementation depends on T026), and US3 can be developed in parallel by different operators.

---

## Parallel Example: User Story 1 tests

```text
# All five test files are independent — start them simultaneously:
T021  modules/loganalytics/tests/positive_baseline_npd.tftest.hcl
T022  modules/loganalytics/tests/positive_baseline_prd.tftest.hcl
T023  modules/loganalytics/tests/primary_shared_key_sensitive.tftest.hcl
T024  terraform/log/tests/plan_zero_diff_npd.tftest.hcl
T025  terraform/log/tests/plan_zero_diff_prd.tftest.hcl
```

---

## Implementation Strategy

**MVP scope = User Story 1** (Phases 1 + 2 + 3, plus the CI workflow T053 from Phase 6 so the MVP lands behind a green pipeline). At that point a consumer in either hub can read `terraform_remote_state.log_<env>.outputs.workspace_resource_id` and wire `azurerm_monitor_diagnostic_setting`, the stack is deterministic (snapshot per env), and the six cross-cutting hard-fails (topology/tenant/region/environment/subscription, plus the retention+quota validations from T006/T012) all work — even though US2's exhaustive scope-rejection tests and US3's bounds tests have not yet had their dedicated coverage.

**Incremental delivery**:

1. MVP: ship US1 → both hub workspaces deploy deterministically; consumers can wire diagnostic settings.
2. +US2: per-env negative coverage + plan-snapshot tests harden the two-env contract.
3. +US3: retention/quota bounds tests harden the observability knobs.
4. Polish (Phase 6): READMEs and the SC grep audit fold into each PR; final fmt/test gate runs in T055.

---

## Format Validation

Every task above conforms to `- [ ] TXXX [P?] [USx?] Description with file path` — verified by inspection. Total: 55 tasks (T001–T055).
