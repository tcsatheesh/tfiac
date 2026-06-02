# Tasks: Services (engine-driven `stack_purpose=svc` stack)

**Input**: Design documents from [specs/006-services/](.) — spec.md (incl.
Clarifications Addendum CA-001..CA-012), plan.md, research.md, data-model.md,
contracts/cross-stack-outputs.md, quickstart.md (all regenerated 2026-05-30).

**Prerequisites**: plan.md (required), spec.md (required for user stories),
research.md (R-1..R-12), data-model.md (§ 1..§ 8 canonical-name catalogue),
contracts/cross-stack-outputs.md.

**Tests**: Tests are MANDATORY in this feature — every wrapper carries
positive + negative `*.tftest.hcl` fixtures, the root stack carries the
nine C-009 fixtures, and the `module.naming.names` snapshot is byte-equal
on every CI run (FR-014 / FR-016 / C-009).

**Organisation**: tasks are grouped into the eight phases mandated by
[plan.md § Phased task structure](plan.md#phased-task-structure-for-speckittasks-to-expand)
(Phase 0 Audit → Phase 7 Live rollout). User-story labels are applied
inside each phase per spec.md US1..US5.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps task to spec.md user story (US1..US5). Phase-0
  audit, Phase-1 root scaffold, Phase-4 migration housekeeping, Phase-5
  CI, Phase-6 verification, and Phase-7 rollout carry NO story label
  (they are infrastructure that blocks every story).

## Path Conventions

- Root stack: [terraform/services/](../../terraform/services/) (CREATED in
  this feature — directory does not currently exist).
- Wrapper modules: [modules/&lt;service&gt;/](../../modules/) (15 per
  [spec.md C-001](spec.md#clarifications) /
  [C-010](spec.md#clarifications); `modules/loganalytics/` already exists
  per [feature 003](../003-log-analytics/) and is re-validated, not
  re-created; the other 14 are CREATED in Phase 2).
- Operator tfvars: [variables/{hub,sp01}/{npd,prd}/services.tfvars.json](../../variables/)
  (seed files CREATED in Phase 4).
- CI workflow: [.github/workflows/deploy.yaml](../../.github/workflows/deploy.yaml)
  (the `service` `choice` extended in Phase 5).
- State backend key: `"{tenant}/{environment}/services.tfstate"` per
  [spec.md C-006](spec.md#clarifications).
- Scratch: [temp/scratchpad/](../../temp/scratchpad/) per CLAUDE.md
  (never `/tmp`).

---

## Phase 0: Audit (read-only pre-work)

**Purpose**: gather facts before any HCL is written. Outputs land in
`temp/scratchpad/006-services-audit/`.

- [ ] T001 [P] Inventory the 15 wrapper directories required by [spec.md C-001](spec.md#clarifications) (`keyvault, storage, loganalytics, appinsights, cntreg, uai, search, openai, aifoundry, language, docint, fnapp, lgapp, aml, apim`); for each note whether `modules/<svc>/` already exists, and capture the AVM-vs-handroll status of `temp/modules/<svc>/` (legacy reference). Write findings to `temp/scratchpad/006-services-audit/wrapper-inventory.md`.
- [ ] T002 [P] Pin AVM module versions for each of the 15 v1 selectable types by querying the Terraform Registry (`Azure/avm-res-*/azurerm`); record `(type → AVM module → pinned version | "no AVM yet")` in `temp/scratchpad/006-services-audit/avm-versions.md`. Day-one AVM-covered list per [research.md R-9](research.md): `keyvault, storage, loganalytics, cntreg, uai, appinsights, search`.
- [ ] T003 [P] Audit `temp/_legacy/services/` (currently only carries `README.md, locals.tf, main.tf, outputs.tf, providers.tf, variables.tf`) for any address that any operator might have applied previously; record findings in `temp/scratchpad/006-services-audit/legacy-moved-candidates.md`. `terraform/services/` does NOT exist today, so no `moved {}` blocks are required UNLESS the audit surfaces a live state under the legacy path (per CLAUDE.md / [spec.md C-004](spec.md#clarifications)).
- [ ] T004 [P] Re-verify the canonical-name shapes in [data-model.md § 5](data-model.md) against `local.top_level_named` in [modules/naming/locals.tf](../../modules/naming/locals.tf) by hand; produce a one-line `actual == expected` confirmation per row in `temp/scratchpad/006-services-audit/canonical-name-recheck.md` (catches CA-001 regressions before any fixture is authored).

**Checkpoint**: audit artefacts complete; no source changes yet.

---

## Phase 1: Root-stack scaffolding (foundational, blocks every story)

**Purpose**: stand up [terraform/services/](../../terraform/services/) so
every Phase-3 fixture can target it. No `[Story]` label — every story
depends on this phase.

- [ ] T005 Create `terraform/services/versions.tf` pinning `required_version = "~> 1.9"` and `required_providers` for `azurerm`, `azapi`, `modtm`, `random`, `time` (the AVM-required set per [plan.md Phase 1](plan.md#phase-1--root-stack-scaffolding-terraformservices) and Constitution Principle IX).
- [ ] T006 Create `terraform/services/providers.tf` with a single `azurerm` provider block carrying `features {}` and `subscription_id = var.subscription_id`, plus inert provider configurations for `azapi`, `modtm`, `random`, `time` (no aliases — wrapper modules inherit per Constitution Principle VII).
- [ ] T007 Create `terraform/services/backend.tf` declaring a partial-config `azurerm` backend with `use_azuread_auth = true` (CI / operator injects `resource_group_name`, `storage_account_name`, `container_name`, `key = "{tenant}/{environment}/services.tfstate"`, `subscription_id` via `-backend-config=...` per [quickstart.md Step 3](quickstart.md) and [spec.md C-006](spec.md#clarifications)).
- [ ] T008 Create `terraform/services/variables.tf` declaring the EIGHT required inputs (`subscription_id`, `topology`, `tenant`, `environment`, `region`, `usecase`, `repo`, `services`) and the optional `overrides` per [data-model.md § 1](data-model.md). Each `variable` block carries the validations enumerated in data-model.md § 1 (GUID regex + placeholder rejection on `subscription_id`; `contains(["hub","spoke"], ...)` on `topology`; `^(hub|sp(0[1-9]|[1-9][0-9]))$` + topology cross-check on `tenant`; `contains(["npd","prd"], ...)` on `environment`; `^[a-z0-9]{3,4}$` on `region`; `^[a-z0-9]{3}$` on `usecase` — tighter than the engine's `^[a-z0-9]{3,4}$` so the CA-004 strategy-B `service_purpose` fallback always satisfies the engine's `^[a-z0-9]{3}$` regex; `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` + length ≤ 256 on `repo`; per-entry rules from [data-model.md § 2](data-model.md) on `services`).
- [ ] T009 Create `terraform/services/locals.tf` per [plan.md Phase 1](plan.md#phase-1--root-stack-scaffolding-terraformservices) and [research.md R-2](research.md): set `stack_purpose = "svc"`, build `naming_input` with the six engine inputs, declare `v1_selectable_types` (the 15-entry C-001 list), `deferred_reason` map (with one-line friendly message per deferred-but-catalogued type — pointing at `terraform/vnet/`, `terraform/dns/`, or "deferred to follow-up"), `type_short` (3-letter slug per type for the synthetic engine key), and `engine_services` (auto-emitted `resource_group` entry + flattened per-instance records per [data-model.md § 3](data-model.md)).
- [ ] T010 Create `terraform/services/main.tf` per [plan.md Phase 1](plan.md#phase-1--root-stack-scaffolding-terraformservices): `data "azurerm_client_config" "current" {}`; `module "naming" { source = "../../modules/naming" input = local.naming_input services = local.engine_services }`; resolve the single RG canonical name as `local.svc_rg_name = one([for k, v in module.naming.names : k if v.service_type == "resource_group"])` and the RG location from the engine's own tag (`local.svc_rg_location = module.naming.names[local.svc_rg_name].tags.region` — the engine has already resolved the short region code to the full Azure region; the stack does NOT reference `module.catalogue` directly because the engine's internal catalogue module is not re-exported); `azurerm_resource_group "svc"` with `name = local.svc_rg_name`, `location = local.svc_rg_location`, `tags = module.naming.names[local.svc_rg_name].tags` (the engine-emitted 8 baseline tags per [data-model.md § 6](data-model.md)); one `module "<type>" { for_each = { for n, e in module.naming.names : n => e if e.service_type == "<type>" } source = "../../modules/<dir>" ... }` invocation per v1 selectable type, keyed by canonical name per [research.md R-6](research.md), passing `canonical_name = each.key`, `engine_record = each.value`, `resource_group_name = azurerm_resource_group.svc.name`, `location = azurerm_resource_group.svc.location`, `overrides = lookup(var.overrides, each.key, {})`.
- [ ] T011 Create `terraform/services/check.tf` carrying three `check` blocks: (a) `subscription_match` over `data.azurerm_client_config.current.subscription_id == var.subscription_id` (mirrors `terraform/vnet/main.tf` per [data-model.md § 1](data-model.md)); (b) `v1_selectable_inventory` emitting one assert per offender from `local.deferred_reason` ([CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases)); (c) `overrides_keys_resolved` over `keys(var.overrides) ⊆ keys(module.naming.names)` listing every unmatched key ([CA-006](spec.md#ca-006--stack-owns-unmatched-overrides-hard-fail-corrects-fr-006-fr-018-c-003)).
- [ ] T012 Create `terraform/services/outputs.tf` declaring exactly the outputs in [contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md): `resource_group_name`, `resource_group_id`, `resource_ids` (map keyed by canonical name → wrapper `resource_id`, merged from every `module.<type>`), `resource_names` (passthrough `{ k = k for k in keys(resource_ids) }`), `naming = module.naming.names`, `engine_version = module.naming.engine_version`. NO per-resource `_id` / `_name` outputs, NO `subscription_id` re-export.
- [ ] T013 Create `terraform/services/README.md` documenting: the 8 required inputs + 1 optional, the 15 v1 selectable types with one-line description each, the C-001 deferred-type table, the state-key contract (`{tenant}/{environment}/services.tfstate`), the output contract (link to [contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md)), and the runtime `subscription_id` injection paths per [CA-011](spec.md#ca-011--subscription_id-runtime-injection-cli-or-env-corrects-c-005-quickstart-troubleshooting).
- [ ] T014 Run `terraform fmt -recursive terraform/services/` and `terraform -chdir=terraform/services init -backend=false && terraform -chdir=terraform/services validate`; resolve any errors before proceeding to Phase 2.

**Checkpoint**: root stack syntactically valid; engine wiring complete;
ready for wrapper modules to slot into the `for_each` invocations in
`main.tf`.

---

## Phase 2: Wrapper-module modernisation (15 modules, US1-enabling)

**Purpose**: build / refactor the 15 wrappers per [spec.md C-010 / FR-021](spec.md#clarifications)
and [research.md R-5 / R-9](research.md). Each wrapper accepts the engine
record + canonical name + RG + location + per-instance overrides,
delegates to AVM (or hand-rolls once with a follow-up tracker), strips
every hardcoded SKU / region / abbreviation / tag, carries no `providers`
block, emits `resource_id` as the primary output, and ships positive +
negative `*.tftest.hcl` fixtures (Constitution defence-in-depth).

All wrappers are labelled `[US1]` because the "operator selects what to
build" promise of US1 is structurally satisfied when every wrapper accepts
the canonical engine contract; US2 (hub), US3 (day-2), US4 (overrides)
and US5 (reject unknown) reuse the same wrappers without further change.

- [ ] T015 [US1] Author a shared wrapper-template reference at `temp/scratchpad/006-services-audit/wrapper-template.md` (variable shapes, AVM module skeleton, tftest skeleton, expected `resource_id` output) so the 15 wrapper tasks below can be implemented in parallel without drift.

### 2A — AVM-covered wrappers (parallelisable after T015)

- [ ] T016 [P] [US1] Create `modules/keyvault/` (`main.tf`, `variables.tf`, `locals.tf` (defaults), `outputs.tf`, `versions.tf`, `README.md`) delegating to `Azure/avm-res-keyvault-vault/azurerm` (version pinned by T002). Accept `canonical_name = "kvshdshdsp01npduks001"`-shaped strings; pass `each.value.tags` (the engine's 8 baseline keys) verbatim to the AVM module; merge `var.overrides` on top of `local.defaults` inside the AVM call.
- [ ] T017 [P] [US1] Create `modules/keyvault/tests/positive.tftest.hcl` (asserts: with a reference engine record for `kvshdshdsp01npduks001`, the plan emits exactly one Key Vault, `name == "kvshdshdsp01npduks001"`, `resource_group_name` is the supplied RG, the 8 baseline tags from [data-model.md § 6](data-model.md) are present) AND `modules/keyvault/tests/negative.tftest.hcl` (asserts: a missing `canonical_name`, a missing `resource_group_name`, or a `canonical_name` that violates `^[a-z0-9]{1,24}$` hard-fails at plan time).
- [ ] T018 [P] [US1] Create `modules/storage/` delegating to `Azure/avm-res-storage-storageaccount/azurerm`; reference name `stshdshdsp01npduks001`.
- [ ] T019 [P] [US1] Create `modules/storage/tests/{positive,negative}.tftest.hcl` against `stshdshdsp01npduks001` / `stshdshdsp01npduks002`.
- [ ] T020 [P] [US1] Re-validate (do NOT re-create) the existing `modules/loganalytics/` from [feature 003](../003-log-analytics/) against the wrapper template from T015: confirm it accepts a `canonical_name = "log-shd-shd-sp01-npd-uks-001"`-shaped string, emits exactly one `azurerm_log_analytics_workspace` with `name == canonical_name`, and surfaces `resource_id`. Open a follow-up task if any drift is found.
- [ ] T021 [P] [US1] Add `modules/loganalytics/tests/services_positive.tftest.hcl` and `modules/loganalytics/tests/services_negative.tftest.hcl` (alongside any feature-003 tests) covering the services-stack consumption path with canonical name `log-shd-shd-sp01-npd-uks-001`.
- [ ] T022 [P] [US1] Create `modules/appinsights/` delegating to the AVM `Azure/avm-res-insights-component/azurerm` (or hand-roll `azurerm_application_insights` with README follow-up tracker if no AVM is published per T002 audit); reference name `appi-shd-shd-sp01-npd-uks-001`.
- [ ] T023 [P] [US1] Create `modules/appinsights/tests/{positive,negative}.tftest.hcl` against `appi-shd-shd-sp01-npd-uks-001`.
- [ ] T024 [P] [US1] Create `modules/cntreg/` delegating to `Azure/avm-res-containerregistry-registry/azurerm`; reference name `crshdshdsp01npduks001`.
- [ ] T025 [P] [US1] Create `modules/cntreg/tests/{positive,negative}.tftest.hcl` against `crshdshdsp01npduks001`.
- [ ] T026 [P] [US1] Create `modules/uai/` delegating to `Azure/avm-res-managedidentity-userassignedidentity/azurerm`; reference name `id-shd-shd-sp01-npd-uks-001`.
- [ ] T027 [P] [US1] Create `modules/uai/tests/{positive,negative}.tftest.hcl` against `id-shd-shd-sp01-npd-uks-001`.
- [ ] T028 [P] [US1] Create `modules/search/` delegating to `Azure/avm-res-search-searchservice/azurerm`; reference name `srch-shd-shd-sp01-npd-uks-001`.
- [ ] T029 [P] [US1] Create `modules/search/tests/{positive,negative}.tftest.hcl` against `srch-shd-shd-sp01-npd-uks-001`.

### 2B — Hand-rolled or partially-covered wrappers (parallelisable after T015)

- [ ] T030 [P] [US1] Create `modules/openai/` delegating to `Azure/avm-res-cognitiveservices-account/azurerm` (with `kind = "OpenAI"`) or hand-roll `azurerm_cognitive_account` per the T002 audit; reference name `oai-shd-shd-sp01-npd-uks-001`. Record any AVM gap in `modules/openai/README.md` follow-up tracker.
- [ ] T031 [P] [US1] Create `modules/openai/tests/{positive,negative}.tftest.hcl` against `oai-shd-shd-sp01-npd-uks-001`.
- [ ] T032 [P] [US1] Create `modules/aifoundry/` (hand-roll `azapi_resource` for AI Foundry hub if no AVM is published per T002); reference name `aif-shd-shd-sp01-npd-uks-001`. Record AVM gap in README.
- [ ] T033 [P] [US1] Create `modules/aifoundry/tests/{positive,negative}.tftest.hcl` against `aif-shd-shd-sp01-npd-uks-001`.
- [ ] T034 [P] [US1] Create `modules/language/` delegating to `Azure/avm-res-cognitiveservices-account/azurerm` (with `kind = "TextAnalytics"`) or hand-roll per T002 audit; reference name `lang-shd-shd-sp01-npd-uks-001`.
- [ ] T035 [P] [US1] Create `modules/language/tests/{positive,negative}.tftest.hcl` against `lang-shd-shd-sp01-npd-uks-001`.
- [ ] T036 [P] [US1] Create `modules/docint/` delegating to `Azure/avm-res-cognitiveservices-account/azurerm` (with `kind = "FormRecognizer"`) or hand-roll per T002 audit; reference name `di-shd-shd-sp01-npd-uks-001`.
- [ ] T037 [P] [US1] Create `modules/docint/tests/{positive,negative}.tftest.hcl` against `di-shd-shd-sp01-npd-uks-001`.
- [ ] T038 [P] [US1] Create `modules/fnapp/` delegating to `Azure/avm-res-web-site/azurerm` (kind `functionapp,linux`) or hand-roll; reference name `func-shd-shd-sp01-npd-uks-001`. Record AVM gap in README if needed.
- [ ] T039 [P] [US1] Create `modules/fnapp/tests/{positive,negative}.tftest.hcl` against `func-shd-shd-sp01-npd-uks-001`.
- [ ] T040 [P] [US1] Create `modules/lgapp/` delegating to `Azure/avm-res-logic-workflow/azurerm` or hand-roll `azurerm_logic_app_workflow`; reference name `logic-shd-shd-sp01-npd-uks-001`.
- [ ] T041 [P] [US1] Create `modules/lgapp/tests/{positive,negative}.tftest.hcl` against `logic-shd-shd-sp01-npd-uks-001`.
- [ ] T042 [P] [US1] Create `modules/aml/` delegating to `Azure/avm-res-machinelearningservices-workspace/azurerm` or hand-roll; reference name `mlw-shd-shd-sp01-npd-uks-001` (length 28 ≤ azure_max 33 per [data-model.md § 5](data-model.md)).
- [ ] T043 [P] [US1] Create `modules/aml/tests/{positive,negative}.tftest.hcl` against `mlw-shd-shd-sp01-npd-uks-001`.
- [ ] T044 [P] [US1] Create `modules/apim/` delegating to `Azure/avm-res-apimanagement-service/azurerm` or hand-roll `azurerm_api_management`; reference name `apim-shd-shd-sp01-npd-uks-001`.
- [ ] T045 [P] [US1] Create `modules/apim/tests/{positive,negative}.tftest.hcl` against `apim-shd-shd-sp01-npd-uks-001`.

### 2C — Per-wrapper validation

- [ ] T046 Run `terraform fmt -recursive modules/` and per-wrapper `terraform -chdir=modules/<svc> init -backend=false && terraform -chdir=modules/<svc> validate && terraform -chdir=modules/<svc> test` for each of the 15 wrappers; resolve every failure before Phase 3.

**Checkpoint**: every v1 selectable type has a wrapper that accepts the
canonical engine contract with green pos + neg tests.

---

## Phase 3: Root-stack `terraform test` suite (C-009 — 9 fixtures + snapshot)

**Purpose**: author the nine mandatory fixtures from [spec.md C-009](spec.md#clarifications)
+ the [FR-014](spec.md#functional-requirements) determinism snapshot.
Every fixture references the corrected canonical-name shapes from
[data-model.md § 5](data-model.md). Path: `terraform/services/tests/`.

- [ ] T047 [P] [US1] Create the determinism snapshot at `terraform/services/tests/snapshots/reference.json` capturing `module.naming.names` for the reference input (`topology=spoke, tenant=sp01, environment=npd, region=uks, usecase=shd, repo="tcsatheesh/tfiac", services = [{ type = "keyvault" }, { type = "storage", count = 2 }]`). Keys MUST include `rg-svc-shd-sp01-npd-uks-001, kvshdshdsp01npduks001, stshdshdsp01npduks001, stshdshdsp01npduks002` and each value MUST contain the 8 baseline tags from [data-model.md § 6](data-model.md).
- [ ] T048 [P] [US1] Create `terraform/services/tests/snapshot.tftest.hcl` — runs `terraform plan` with the reference input, computes the byte-equal SHA256 of `jsonencode(module.naming.names)` and asserts equality against the committed snapshot ([FR-014](spec.md#functional-requirements)).
- [ ] T049 [P] [US1] Create `terraform/services/tests/happy_spoke.tftest.hcl` (C-009 #2) — reference input `topology=spoke, tenant=sp01, services = [{type="keyvault"},{type="storage",count=2}]`; asserts 1 RG (`rg-svc-shd-sp01-npd-uks-001`) + 3 service resources (`kvshdshdsp01npduks001, stshdshdsp01npduks001, stshdshdsp01npduks002`), all in the `svc` RG, every resource carries the 8 baseline tags.
- [ ] T050 [P] [US2] Create `terraform/services/tests/happy_hub.tftest.hcl` (C-009 #3) — `topology=hub, tenant=hub, environment=npd, region=uks, usecase=shd, services = [{type="keyvault"},{type="log_analytics"}]`; asserts RG name `rg-svc-shd-hub-npd-uks-001`, keyvault `kvshdshdhubnpduks001`, log_analytics `log-shd-shd-hub-npd-uks-001`.
- [ ] T051 [P] [US5] Create `terraform/services/tests/reject_unknown_service.tftest.hcl` (C-009 #4) — `services = [{ type = "frobnicate" }]` hard-fails at plan time with the `v1_selectable_inventory` `check`-block message naming `frobnicate`.
- [ ] T052 [P] [US5] Create `terraform/services/tests/reject_prd_hub_only.tftest.hcl` (C-009 #5) — `services = [{ type = "dns_zone" }]` AND a sibling assert for `[{ type = "private_dns_zone" }]` each hard-fail at plan time with a message naming the owning stack (`terraform/dns/`) per [CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases).
- [ ] T053 [P] [US5] Create `terraform/services/tests/reject_deferred_v1.tftest.hcl` (C-009 #6) — `services = [{ type = "firewall" }]` AND a spoke-only deferred type (`vm`) each hard-fail at plan time with the "deferred to follow-up" message from `local.deferred_reason`.
- [ ] T054 [P] [US1] Create `terraform/services/tests/idempotent_reorder.tftest.hcl` (C-009 #7) — runs two plans with `services` entries reordered while `(type, count, purpose)` triplets stay identical; asserts byte-equal `module.naming.names` keys and zero `for_each`-key churn per [research.md R-6](research.md) and [FR-015](spec.md#functional-requirements).
- [ ] T055 [P] [US5] Create `terraform/services/tests/deferred_pe_diag_rejected.tftest.hcl` (C-009 #8) — `services = [{ type = "keyvault", private_endpoints = [{}] }]` AND a sibling assert with `diagnostic_settings = [{}]` each hard-fail at plan time with the friendly "deferred to follow-up; see spec.md A4" message from the `variable "services"` validation in T008.
- [ ] T056 [P] [US4] Create `terraform/services/tests/override_targets_one_instance.tftest.hcl` (C-009 #9) — `services = [{ type = "keyvault", count = 2 }]` with `overrides = { "kvshdshdsp01npduks001" = { sku_name = "premium" } }`; asserts instance `001` carries `premium` and instance `002` carries the wrapper's `local.defaults.sku_name` from `modules/keyvault/locals.tf`. Includes a sibling fixture for an unmatched override key (`{ "kv-nonexistent-001" = {} }`) asserting the `overrides_keys_resolved` check fires.
- [ ] T057 Run `terraform -chdir=terraform/services init -backend=false && terraform -chdir=terraform/services test`; resolve every failure before Phase 4.

**Checkpoint**: all nine C-009 fixtures + the snapshot are green; root
stack independently verifiable.

---

## Phase 4: Operator-input seeds & migration housekeeping

**Purpose**: ship the four per-tenant `services.tfvars.json` seed files,
draft the PR body (including the "Operator approval required" section
required by [spec.md C-004 / FR-023](spec.md#clarifications) if Phase 0
T003 surfaces any forced recreates), and audit for `moved {}` need.

- [ ] T058 [P] Create `variables/hub/npd/services.tfvars.json` with the eight required inputs (`subscription_id = "REPLACE-WITH-RUNTIME-SUBSCRIPTION-ID"`, `topology="hub"`, `tenant="hub"`, `environment="npd"`, `region="uks"`, `usecase="shd"`, `repo="tcsatheesh/tfiac"`, `services = []` initially) + empty `overrides = {}`. Format per [quickstart.md Step 1](quickstart.md).
- [ ] T059 [P] Create `variables/hub/prd/services.tfvars.json` (same shape as T058 with `environment="prd"`).
- [ ] T060 [P] Create `variables/sp01/npd/services.tfvars.json` (same shape as T058 with `topology="spoke"`, `tenant="sp01"`, `environment="npd"`).
- [ ] T061 [P] Create `variables/sp01/prd/services.tfvars.json` (same shape with `tenant="sp01"`, `environment="prd"`); creates the `variables/sp01/prd/` directory if it does not exist.
- [ ] T062 Author `temp/scratchpad/006-services-pr-body.md` summarising the feature, listing the 15 wrappers added/refactored, linking each Phase-3 fixture, and including an "Operator approval required" section. If Phase-0 T003 surfaced any live legacy state under `terraform/services/` whose addresses cannot be `moved {}`-translated without recreation, list each such address; otherwise state explicitly "No forced recreates — `terraform/services/` is being CREATED; no `moved {}` blocks required."
- [ ] T063 Decide whether `terraform/services/moved.tf` is required: ONLY if T003 surfaced legacy addresses that would otherwise destroy/recreate. If required, author the file with one `moved {}` block per address per [plan.md Phase 4](plan.md#phase-4--migration-of-the-existing-terraformservices-stack); if not, this task is a no-op and the explicit absence is noted in `temp/scratchpad/006-services-pr-body.md`.

**Checkpoint**: operator-input seeds in place; PR body draft ready;
migration scope decided.

---

## Phase 5: CI wiring

**Purpose**: extend [.github/workflows/deploy.yaml](../../.github/workflows/deploy.yaml)
so the `service` `workflow_dispatch` choice accepts `"services"`, with the
same OIDC + state-SA + `subscription_id` injection used by `vnet`.

- [ ] T064 Edit `.github/workflows/deploy.yaml` line 14 to add `services` to the `service` `choice` `options` list: change `options: [vnet, dns, log, buildsvr]` → `options: [vnet, dns, log, buildsvr, services]` per [spec.md C-006](spec.md#clarifications).
- [ ] T065 Confirm the workflow's existing `terraform plan` / `apply` steps reuse the same `-var "subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"` injection per [CA-011](spec.md#ca-011--subscription_id-runtime-injection-cli-or-env-corrects-c-005-quickstart-troubleshooting), the same OIDC federated-identity login, and the same temporary state-SA firewall allowlist + restore steps used by `vnet`. If `services` requires no workflow-step changes beyond T064, document that in `temp/scratchpad/006-services-pr-body.md`; otherwise patch the workflow steps to add `services` to any per-stack `case`/`if` matrix.

**Checkpoint**: `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=npd -f action=apply -f apply=false` dispatches successfully (plan-only smoke).

---

## Phase 6: Verification gates (the merge bar)

**Purpose**: run every gate required by Constitution v2.2.0 +
[spec.md SC-001..SC-008](spec.md#measurable-outcomes) +
[plan.md Phased task structure](plan.md#phased-task-structure-for-speckittasks-to-expand)
before the PR is raised.

- [ ] T066 Run `terraform fmt -recursive` at the repo root; assert zero changes (formatting clean across all of `terraform/` and `modules/`).
- [ ] T067 Run `terraform -chdir=terraform/services init -backend=false && terraform -chdir=terraform/services validate` AND `terraform -chdir=modules/<svc> init -backend=false && terraform -chdir=modules/<svc> validate` for each of the 15 wrappers; assert zero validation errors anywhere.
- [ ] T068 Run `terraform -chdir=terraform/services test` AND `terraform -chdir=modules/<svc> test` for each of the 15 wrappers; assert every fixture (9 root + 30 wrapper) is green.
- [ ] T069 Double-plan determinism check: with a live backend init against the `sp01/npd` state key and `subscription_id` injected per [quickstart.md Step 2](quickstart.md), run `terraform plan -out=plan1.tfplan -var-file=variables/sp01/npd/services.tfvars.json` twice; assert the second plan reports `0 to add, 0 to change, 0 to destroy` per [SC-002](spec.md#measurable-outcomes). Stash plan outputs in `temp/scratchpad/006-services-audit/double-plan-{1,2}.txt`.
- [ ] T070 Snapshot byte-equality check: run `terraform -chdir=terraform/services test -filter=tests/snapshot.tftest.hcl`; assert SHA256 byte-equal against the committed `terraform/services/tests/snapshots/reference.json` ([SC-006](spec.md#measurable-outcomes)).
- [ ] T071 Run the CORRECTED [CA-009](spec.md#ca-009--sc-007-grep-must-match-real-name-shapes-corrects-sc-007-tasksmd-verification-gate-8) hand-built-name grep gate (the only [SC-007](spec.md#measurable-outcomes) gate that is valid; the prior regex was vacuous):

   ```sh
   git grep -nE \
     '(^|[^a-z])(rg-svc-|kv[a-z0-9]{3,4}[a-z0-9]{3,4}|st[a-z0-9]{3,4}[a-z0-9]{3,4}|cr[a-z0-9]{3,4}[a-z0-9]{3,4}|(log|appi|id|apim|func|logic|mlw|oai|aif|lang|di|srch)-[a-z0-9]{3}-[a-z0-9]{3,4}-(hub|sp[0-9]{2}))-' \
     terraform/services modules/{keyvault,storage,appinsights,loganalytics,cntreg,uai,search,openai,aifoundry,language,docint,fnapp,lgapp,aml,apim} \
     -- ':!*/tests/*' ':!*/README.md'
   ```

   Assert ZERO matches outside `tests/` and `README.md` ([SC-007](spec.md#measurable-outcomes) per [CA-009](spec.md#ca-009--sc-007-grep-must-match-real-name-shapes-corrects-sc-007-tasksmd-verification-gate-8)).
- [ ] T072 AVM-delegation check: for every wrapper claimed AVM-covered in T002, confirm the wrapper file contains exactly one `module "<avm>" { source = "Azure/avm-res-*/azurerm" }` block and zero `azurerm_*` / `azapi_*` resource blocks ([SC-008](spec.md#measurable-outcomes)); for wrappers with no AVM, confirm the README carries an explicit follow-up tracker.

**Checkpoint**: every Constitution + Spec gate green; PR ready to raise.

---

## Phase 7: Live rollout (post-merge, CLAUDE.md step 4)

**Purpose**: roll out on `master` per CLAUDE.md autonomy rules, then
restore the state-SA firewall lockdown.

- [ ] T073 After PR squash-merge: `git checkout master && git pull --ff-only`; confirm `terraform/services/` is present on `master`.
- [ ] T074 Temporarily allowlist the runner IP on the hub-internal state SA (mirroring the bootstrap / vnet pattern); record the change in `temp/scratchpad/006-services-rollout-fw.md`.
- [ ] T075 For each live `(tenant, environment)` pair (`(hub, npd)`, `(hub, prd)`, `(sp01, npd)`, `(sp01, prd)`), run `terraform -chdir=terraform/services init -backend-config=key={tenant}/{environment}/services.tfstate ...` followed by `terraform plan -var-file=../../variables/{tenant}/{environment}/services.tfvars.json -var "subscription_id=$AZURE_SUBSCRIPTION_ID"`; archive each plan under `temp/scratchpad/006-services-rollout-{tenant}-{environment}-plan.txt`. Apply only after operator visual confirmation per CLAUDE.md and only against pairs whose plans are clean.
- [ ] T076 Restore the state-SA firewall lockdown per CLAUDE.md (`publicNetworkAccess=Disabled`, `defaultAction=Deny`, remove the temporary runner IP added in T074); confirm via `az storage account show ... --query "networkRuleSet"` and append the confirmation to `temp/scratchpad/006-services-rollout-fw.md`.

**Checkpoint**: services stack is live on every applicable `(tenant,
environment)` pair; state SA is locked down.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 0 (Audit)**: no dependencies — start immediately.
- **Phase 1 (Root scaffold)**: depends on Phase 0 (audit findings shape `locals.tf`, AVM versions).
- **Phase 2 (Wrappers)**: depends on Phase 1 T015 only (wrapper template); after T015 the 14 created wrappers + 1 re-validated wrapper run in parallel.
- **Phase 3 (Root tests)**: depends on Phase 1 + Phase 2 (the wrappers must exist for `module.<type>` invocations to resolve).
- **Phase 4 (Seeds / PR body)**: depends on Phase 0 T003 (migration audit) and may run in parallel with Phase 3.
- **Phase 5 (CI)**: depends on Phase 1 (the workflow needs `terraform/services/` to exist).
- **Phase 6 (Verification)**: depends on Phases 1–5 (all gates run end-to-end).
- **Phase 7 (Rollout)**: depends on PR merge (post-merge only per CLAUDE.md).

### User Story Dependencies

- **US1 (P1, MVP — spoke happy path)**: requires Phases 0 + 1 + 2 (T015 + all `[US1]`-labelled wrappers) + Phase 3 T047–T049 + T054.
- **US2 (P1 — hub topology)**: piggybacks on US1's wrappers; adds Phase 3 T050. No new wrappers.
- **US3 (P2 — day-2 add)**: structurally satisfied by Phase 3 T054 (reorder zero-diff) and Phase 6 T069 (double-plan). No dedicated fixture per C-009 minimum.
- **US4 (P2 — overrides)**: requires `modules/keyvault/locals.tf::defaults` (T016) + Phase 3 T056.
- **US5 (P1 — reject unknowns)**: requires Phase 1 T008 + T011 (`v1_selectable_inventory` + `services` validations) + Phase 3 T051 + T052 + T053 + T055.

### Within Each Wrapper (Phase 2)

- `versions.tf` + `variables.tf` first; `main.tf` + `locals.tf` (defaults) second; `outputs.tf` third; `tests/{positive,negative}.tftest.hcl` last; per-wrapper `terraform fmt && validate && test` at T046.

---

## Parallel Opportunities

- **Phase 0**: T001–T004 all `[P]` — run together.
- **Phase 2 after T015**: T016–T045 all `[P]` (15 disjoint module directories × 2 tasks each) — fan out to as many workers as available.
- **Phase 3 after Phase 2**: T047–T056 all `[P]` (each is a different `*.tftest.hcl` file under `terraform/services/tests/`).
- **Phase 4**: T058–T061 all `[P]` (4 disjoint tfvars files).

## Parallel Example: Phase 2 wrapper sprint

```bash
# After T015 lands, launch the 15 wrappers in parallel:
Task: "Create modules/keyvault/ delegating to Azure/avm-res-keyvault-vault/azurerm; reference name kvshdshdsp01npduks001"
Task: "Create modules/storage/ delegating to Azure/avm-res-storage-storageaccount/azurerm; reference name stshdshdsp01npduks001"
Task: "Create modules/cntreg/ delegating to Azure/avm-res-containerregistry-registry/azurerm; reference name crshdshdsp01npduks001"
Task: "Create modules/uai/ delegating to Azure/avm-res-managedidentity-userassignedidentity/azurerm; reference name id-shd-shd-sp01-npd-uks-001"
Task: "Create modules/search/ delegating to Azure/avm-res-search-searchservice/azurerm; reference name srch-shd-shd-sp01-npd-uks-001"
# ...and the rest, each in its own modules/<svc>/ tree
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Phase 0 audit (T001–T004).
2. Phase 1 root scaffold (T005–T014).
3. Phase 2: only the three MVP wrappers (`keyvault`, `storage`, `loganalytics`) — T015, T016–T017, T018–T019, T020–T021, T046 (subset).
4. Phase 3: the snapshot + happy_spoke + idempotent_reorder fixtures — T047–T049, T054, T057 (subset).
5. **STOP and VALIDATE**: run T069 double-plan on a real `sp01/npd` backend; confirm 0/0/0 second plan.
6. Demo / freeze the MVP increment.

### Incremental Delivery

1. MVP increment (above).
2. Add US2 — T050; demo the hub variant.
3. Add US5 — T051–T053 + T055; demo the friendly hard-fails.
4. Add US4 — T056 (with overrides on the existing `modules/keyvault/`).
5. Build out the remaining 12 wrappers (Phase 2B) in priority order driven by real workload demand.
6. Phase 5 (CI) + Phase 6 (gates) before PR.
7. Phase 7 (rollout) post-merge.

### Parallel Team Strategy

With multiple operators:

1. One operator drives Phases 0 + 1 (linear, single-file edits across `terraform/services/`).
2. After T015 lands, fan 15 operators across the wrappers (Phase 2A + 2B).
3. One operator drives Phase 3 fixtures in parallel with the wrapper sprint (the `for_each` invocations in `main.tf` are already in place from T010).
4. One operator drives Phase 4 seeds + PR body.
5. One operator drives Phase 5 CI patch.
6. PR author drives Phase 6 gates serially.

---

## Notes

- **`terraform/services/` is CREATED in this feature**; no `moved {}`
  blocks are required UNLESS T003 surfaces live legacy state under the
  same path. Any forced recreate goes under "Operator approval required"
  in `temp/scratchpad/006-services-pr-body.md` per
  [spec.md C-004 / FR-023](spec.md#clarifications).
- Every fixture and test references the CORRECT canonical-name shapes
  from [data-model.md § 5](data-model.md) — hyphenated for `rg`, `log`,
  `appi`, `id`, `srch`, `oai`, `aif`, `lang`, `di`, `func`, `logic`,
  `mlw`, `apim`; concatenated for `kv`, `st`, `cr`. Any deviation is a
  [CA-001](spec.md#ca-001--real-canonical-name-formats-corrects-fr-009-fr-010-examples-in-c-001c-009-us1-us2-us4) regression.
- The SC-007 grep gate in T071 is the CORRECTED regex from
  [CA-009](spec.md#ca-009--sc-007-grep-must-match-real-name-shapes-corrects-sc-007-tasksmd-verification-gate-8);
  the prior regex matched nothing real and was vacuous.
- Every wrapper carries both positive AND negative `*.tftest.hcl`
  fixtures per [C-010](spec.md#clarifications) and the
  defence-in-depth promise of [C-011](spec.md#clarifications).
- Engine output consumed is `module.naming.names` (NOT `all_names` —
  the internal local is `local.all_names` but the exposed output key is
  `names`) per [CA-010](spec.md#ca-010--naming-output-passthrough-corrects-contractscross-stack-outputsmd-output-naming).
- Eight baseline tag keys (NOT six) per
  [CA-008](spec.md#ca-008--eight-baseline-tags-not-six-corrects-fr-012).
- Eight required root inputs + one optional `overrides` per
  [CA-002](spec.md#ca-002--usecase-is-the-8th-required-stack-input-corrects-fr-001-a2a5)
  and [data-model.md § 1](data-model.md).
- Scratch artefacts live in `temp/scratchpad/006-services-*` per
  CLAUDE.md (never `/tmp`).

---

## Phase 8 — Amendment 2026-05-31 (APIM hub-only + shared hub LA)

Implements [spec.md C-013](spec.md#c-013--apim-is-hub-only-narrows-fr-007--ca-003--specmd-c-001)
and [spec.md C-014](spec.md#c-014--all-services-emit-diagnostics-to-the-shared-hub-la-narrows-fr-018-a4)
on the already-implemented 006-services-impl branch. All tasks are
post-implement (the wrappers, root stack, and CI exist; this phase
amends them).

### Phase 8.A — APIM hub-only (C-013)

- [X] T080 Add `variable "topology"` (string, validation: `contains(["hub","spoke"], …)`) to `modules/apim/variables.tf`.
- [X] T081 Add a `lifecycle.precondition` (or top-of-file validation) in `modules/apim/main.tf` (or new `modules/apim/check.tf`) that hard-fails when `var.topology != "hub"` with the C-013 message.
- [X] T082 Plumb `topology = var.topology` from `module "apim"` in `terraform/services/main.tf`.
- [X] T083 Add a `lifecycle.precondition` on `azurerm_resource_group.svc` (or a fresh `terraform/services/validations.tf` null_resource) that hard-fails when `var.topology != "hub" && length([for s in var.services : s if s.type == "apim"]) > 0` with the C-013 message.
- [X] T084 [P] Audit `variables/sp01/{npd,prd}/services.tfvars.json` for any `{ "type": "apim" }` entries — remove if present (per repo state on 2026-05-31: files do not yet exist, no edit required; this task is a recorded no-op for the audit trail).

### Phase 8.B — Shared hub LA wiring (C-014)

- [X] T085 Add three new optional `tfstate_*` inputs to `terraform/services/variables.tf` (`tfstate_resource_group`, `tfstate_storage_account`, `tfstate_container`) with defaults `rg-tfs-shd-hub-npd-swc-001` / `sttfsshdhubnpdswc001` / `tfstate`, each with a regex validation.
- [X] T086 Create `terraform/services/data.log.tf` with `data "terraform_remote_state" "hub_log"` keyed by `hub/${var.environment}/log.tfstate` and a stack-local `shared_la_workspace_id`.
- [X] T087 [P] Add `variable "shared_log_analytics_workspace_id"` (regex-validated) and `variable "diagnostic_settings_enabled"` (bool, default `true`) to every diagnostic-capable wrapper under `modules/{keyvault,storage,appinsights,cntreg,search,openai,aifoundry,language,docint,fnapp,lgapp,aml,apim}/variables.tf`. (uai and loganalytics exempt.)
- [X] T088 [P] Add a default `resource "azurerm_monitor_diagnostic_setting" "to_hub_la"` (gated by `var.diagnostic_settings_enabled`) to every diagnostic-capable wrapper's `main.tf`. Use `enabled_log { category_group = "allLogs" }` + `metric { category = "AllMetrics" }`.
- [X] T089 Update `modules/appinsights/main.tf` to set `workspace_id = var.shared_log_analytics_workspace_id` on the underlying `azurerm_application_insights`.
- [X] T090 Plumb `shared_log_analytics_workspace_id = local.shared_la_workspace_id` (and where applicable, `topology = var.topology`) into every wrapper invocation in `terraform/services/main.tf`. Document the `log_analytics` wrapper exemption inline.

### Phase 8.C — Tests (CLAUDE.md: positive + negative for every new variable / code path)

- [X] T091 Create `terraform/services/tests/` directory with `_fixtures.tftest.hcl` defining shared variables + `override_data` for `data.terraform_remote_state.hub_log` and `data.azurerm_client_config.current`.
- [X] T092 Create `terraform/services/tests/reject_apim_spoke.tftest.hcl` — `topology=spoke`, `services=[{type=apim}]` ⇒ plan fails with the C-013 message.
- [X] T093 Create `terraform/services/tests/happy_apim_hub.tftest.hcl` — `topology=hub`, `services=[{type=apim}]` ⇒ plan succeeds.
- [X] T094 Create `terraform/services/tests/diag_wired_to_hub_la.tftest.hcl` — assert every emitted `azurerm_monitor_diagnostic_setting` references the stub workspace id.
- [X] T095 [P] Append a diag-wired assertion to every existing wrapper `positive.tftest.hcl` for diagnostic-capable wrappers; add a `negative` test for the new `shared_log_analytics_workspace_id` regex validation.
- [X] T096 [P] For `modules/apim/`: append a positive `topology=hub` and negative `topology=spoke` (or invalid) test.

### Phase 8.D — Docs

- [X] T097 Append a "2026-05-31 amendment" subsection at the bottom of `specs/006-services/data-model.md` documenting the 3 new `tfstate_*` inputs + the per-wrapper `shared_log_analytics_workspace_id` / `diagnostic_settings_enabled` inputs.
- [X] T098 Append two new failure modes to `specs/006-services/quickstart.md` Troubleshooting: (a) "apim selected on a spoke" → C-013; (b) "shared LA state lookup failed" → run `terraform/log/` first.
- [X] T099 [P] Add a one-line "Defaults" bullet to every diagnostic-capable wrapper's `README.md` documenting the C-014 wiring.

### Phase 8.E — Verification gates (HARD)

- [X] T100 `terraform fmt -recursive` → no changes.
- [X] T101 `terraform validate` in `terraform/services/` + every modified wrapper → success.
- [X] T102 `terraform test` in every modified wrapper + `terraform/services/` → 100% pass.
- [X] T103 Double-plan determinism preserved (deferred to live-apply step per CLAUDE.md; covered by existing snapshot test once it is rebuilt).
- [X] T104 SC-007 grep (CA-009 regex) zero matches outside tests/ + README — no new violations introduced by this amendment.
- [X] T105 No fictional engine FR-NNN citations added.
- [X] T106 Append "Amendment 2026-05-31" section to `temp/scratchpad/006-services-pr-body.md` summarising operator-approval items.

## Phase C-016 — services environment allowlist (dev/pre/prd)

Implements [spec.md C-016](spec.md#c-016) / FR-025 on the shipped
006-services stack. Narrows `var.environment` to `{dev, pre, prd}`,
widens `var.usecase` to allow 3–4 chars, and relocates the sp01 fixture
from the legacy `npd` slot to `dev`. All tasks are post-implement.

### Phase C-016.A — Schema + validation (terraform/services/)

- [X] T-C016-001 Narrow `var.environment` in [terraform/services/variables.tf](../../terraform/services/variables.tf) to allowlist `["dev","pre","prd"]` with a `validation` block whose `error_message` cites FR-025 / C-016 (e.g. `environment must be one of dev|pre|prd (C-016 / FR-025); 'npd' is reserved for shared/hub stacks`). (FR-025 / C-016)
- [X] T-C016-002 Widen `var.usecase` regex in [terraform/services/variables.tf](../../terraform/services/variables.tf) from `^[a-z0-9]{3}$` to `^[a-z0-9]{3,4}$` and update the `error_message` to read `usecase must be 3–4 lowercase alphanumerics (C-016 / FR-025)`. (FR-025 / C-016)
- [X] T-C016-003 Add a `check "environment_workload_only"` block in [terraform/services/check.tf](../../terraform/services/check.tf) asserting `contains(["dev","pre","prd"], var.environment)` with a C-016 / FR-025 error message (defence-in-depth alongside the variable validation). (FR-025 / C-016)

### Phase C-016.B — Tests (terraform/services/tests/)

- [X] T-C016-004 Create [terraform/services/tests/reject_npd_environment.tftest.hcl](../../terraform/services/tests/reject_npd_environment.tftest.hcl) modelled on [terraform/services/tests/reject_apim_spoke.tftest.hcl](../../terraform/services/tests/reject_apim_spoke.tftest.hcl): a `plan` run with `environment = "npd"` (everything else valid) that `expect_failures = [var.environment]` and asserts the C-016 / FR-025 message is surfaced. (FR-025 / C-016)
- [X] T-C016-005 [P] Edit [terraform/services/tests/_fixtures.tftest.hcl](../../terraform/services/tests/_fixtures.tftest.hcl): replace every `environment = "npd"` with `environment = "dev"` so the shared fixture matches the new allowlist. (FR-025 / C-016)
- [X] T-C016-006 [P] Edit [terraform/services/tests/diag_wired_to_hub_la.tftest.hcl](../../terraform/services/tests/diag_wired_to_hub_la.tftest.hcl): replace `environment = "npd"` with `environment = "dev"`. (FR-025 / C-016)
- [X] T-C016-007 [P] Edit [terraform/services/tests/happy_apim_hub.tftest.hcl](../../terraform/services/tests/happy_apim_hub.tftest.hcl): replace `environment = "npd"` with `environment = "dev"` (apim topology assertion is environment-agnostic). (FR-025 / C-016)
- [X] T-C016-008 [P] Edit [terraform/services/tests/reject_apim_spoke.tftest.hcl](../../terraform/services/tests/reject_apim_spoke.tftest.hcl): replace `environment = "npd"` with `environment = "dev"` (the assertion is on `topology`, not environment). (FR-025 / C-016)

### Phase C-016.C — tfvars relocation (variables/sp01/)

- [X] T-C016-009 `git mv variables/sp01/npd/services.tfvars.json variables/sp01/dev/services.tfvars.json` (create `variables/sp01/dev/` first if it does not exist). (FR-025 / C-016)
- [X] T-C016-010 Edit [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json): set `"environment": "dev"` (was `"npd"`) and `"usecase": "uc1"` (was `"shd"`). Leave the services array (KV, SA, aifoundry, aifoundry_project) unchanged. (FR-025 / C-016)
- [X] T-C016-011 Run `rmdir variables/sp01/npd 2>/dev/null || true` — removes the now-empty legacy directory; no-op if other files remain. (FR-025 / C-016)

### Phase C-016.D — CI pipeline (.github/workflows/)

- [X] T-C016-012 Widen `inputs.environment.options` in [.github/workflows/deploy.yaml](../../.github/workflows/deploy.yaml) from `[npd, prd]` to `[npd, prd, dev, pre]` (npd retained for the hub/shared stacks). (FR-025 / C-016)

### Phase C-016.E — Verification gates (HARD)

- [X] T-C016-013 `terraform fmt -recursive` from repo root → no changes. (FR-025 / C-016)
- [X] T-C016-014 [P] `terraform -chdir=modules/naming test` → 100% pass (allowlist change should not regress naming). (FR-025 / C-016)
- [X] T-C016-015 [P] `terraform -chdir=modules/aifoundry test` → 100% pass. (FR-025 / C-016)
- [X] T-C016-016 [P] `terraform -chdir=modules/aifoundryproject test` → 100% pass. (FR-025 / C-016)
- [X] T-C016-017 `terraform -chdir=terraform/services test` → 100% pass (new `reject_npd_environment` test green; relocated positive fixtures green). (FR-025 / C-016)

### Phase C-016.F — Rollout

- [ ] T-C016-018 Push branch, open PR against `master`, squash-merge, delete remote+local branch per CLAUDE.md autonomy rules. (FR-025 / C-016)
- [ ] T-C016-019 Trigger `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=apply -f apply=true` (or equivalent dispatch) on `master`. (FR-025 / C-016)
- [ ] T-C016-020 Verify with `az resource list -g rg-svc-uc1-sp01-dev-swc-001 -o table` that exactly 4 resources are present (KV, SA, aifoundry, aifoundry_project). (FR-025 / C-016)

### Phase C-016.G — Analyze remediation (BLOCKER + MAJOR findings)

- [X] T-C016-021 [P] Edit `.github/workflows/services.yml`: replace `variables/sp01/npd/services.tfvars.json` with `variables/sp01/dev/services.tfvars.json` on BOTH the `pull_request.paths` (~line 24) and `push.paths` (~line 48) lists. Keep `hub/npd`, `hub/prd`, and any other tenant/env entries intact. (Satisfies analyze BLOCKER B1 / FR-025.)
- [X] T-C016-022 [P] Edit `terraform/services/README.md`: replace `variables/sp01/npd/services.tfvars.json` with `variables/sp01/dev/services.tfvars.json` at ~lines 66 and 71 (operator quick-start commands). (Satisfies analyze MAJOR M1 / C-016.)
- [X] T-C016-023 [P] Edit `specs/006-services/quickstart.md`: replace `sp01/npd` references at ~lines 94, 113, 125, 161 with `sp01/dev` (both tfvars path AND backend state-key). (Satisfies analyze MAJOR M2 / C-016.)
- [X] T-C016-024 [P] Edit `specs/006-services/contracts/cross-stack-outputs.md` ~line 201: refresh the `terraform_remote_state` example from `key = "sp01/npd/services.tfstate"` to `key = "sp01/dev/services.tfstate"`. (Satisfies analyze MINOR m1.)
- [X] T-C016-025 Clarification for T-C016-012: when widening `.github/workflows/deploy.yaml` `inputs.environment.options`, preserve `default: npd` verbatim — do NOT change the default. Only the `options` list is widened. (Plan §5 sub-note.)

## Phase C-017 — Foundry account + project (Cognitive Services kind=AIServices + accounts/projects child)

Implements [spec.md C-017](spec.md#c-017) / FR-026 on the shipped
006-services stack. Replaces the legacy `Microsoft.MachineLearningServices/workspaces`
hub + project pair with a single `Microsoft.CognitiveServices/accounts`
(kind=AIServices, `allowProjectManagement=true`) and one
`Microsoft.CognitiveServices/accounts/projects` child. Day-one tfvars
drops the legacy KV + SA fixtures. All tasks are post-implement.

### Phase C-017.A — Pre-merge cleanup (HARD pre-condition)

- [X] T-C017-001 Trigger `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=destroy -f apply=true` on `master` to destroy the currently-deployed legacy resources (KV, SA, aifoundry Hub workspace, aifoundry project workspace) in `rg-svc-uc1-sp01-dev-swc-001`. Wait for the run to complete green before proceeding. (FR-026 / C-017)
- [X] T-C017-002 If Key Vault soft-delete leaves a tombstone after T-C017-001, run `az keyvault purge --name kvuc1uc1sp01devswc001 --location swedencentral` to free the name for any (unlikely) future re-use. (FR-026 / C-017)
- [X] T-C017-003 Temp-open the state SA firewall (`sttfsshdhubnpdswc001`) for the current egress IP, run `az storage blob delete --account-name sttfsshdhubnpdswc001 --container-name tfstate --name sp01/dev/services.tfstate --auth-mode login`, then restore the firewall (`publicNetworkAccess=Disabled`, `defaultAction=Deny`, remove the temp IP) per CLAUDE.md rollout discipline. (FR-026 / C-017)

### Phase C-017.B — modules/aifoundry/ refactor (Cognitive Services account)

- [X] T-C017-004 Rewrite [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf) per [plan.md §1](plan.md): switch the `azapi_resource` type to `Microsoft.CognitiveServices/accounts@2025-09-01`, set the body to `kind=AIServices` + `properties.allowProjectManagement=true` + `properties.customSubDomainName=var.canonical_name` + `sku.name=S0` + `identity.type=SystemAssigned`, and set `response_export_values = ["id","properties.endpoints"]`. Keep the existing `azurerm_monitor_diagnostic_setting` block referencing `azapi_resource.this.id`. (FR-026 / C-017)
- [X] T-C017-005 Edit [modules/aifoundry/variables.tf](../../modules/aifoundry/variables.tf) per [plan.md §2](plan.md): remove the `storage_account_id` and `key_vault_id` variable blocks entirely (no longer required by the Cognitive Services account). (FR-026 / C-017)
- [X] T-C017-006 Edit [modules/aifoundry/locals.tf](../../modules/aifoundry/locals.tf) per [plan.md §3](plan.md): drop the legacy `kind` and `sku_name` defaults; keep `public_network_access = "Enabled"` (still consumed by the body). (FR-026 / C-017)
- [X] T-C017-007 Refresh [modules/aifoundry/README.md](../../modules/aifoundry/README.md) per [plan.md §4](plan.md): document the new Cognitive Services account shape, the removed `storage_account_id` / `key_vault_id` inputs, and the C-017 / FR-026 rationale. (FR-026 / C-017)
- [X] T-C017-008 Edit [modules/aifoundry/tests/positive.tftest.hcl](../../modules/aifoundry/tests/positive.tftest.hcl) per [plan.md §5](plan.md): drop the `storage_account_id` and `key_vault_id` fixture inputs; the wrapper must plan-green standalone with only the remaining inputs. (FR-026 / C-017)
- [X] T-C017-009 Edit [modules/aifoundry/tests/negative.tftest.hcl](../../modules/aifoundry/tests/negative.tftest.hcl) per analyze MAJOR M2: KEEP the existing `empty_canonical_name_rejected` run unchanged (still valuable), and drop the `storage_account_id` / `key_vault_id` lines from its `variables {}` block (those variables disappear in T-C017-005). No new negative required. (FR-026 / C-017)
- [X] T-C017-010 Edit [modules/aifoundry/tests/shared_la_regex_negative.tftest.hcl](../../modules/aifoundry/tests/shared_la_regex_negative.tftest.hcl) per [plan.md §5](plan.md): drop any storage/keyvault fixture inputs (the LA-regex assertion itself is unchanged). (FR-026 / C-017)

### Phase C-017.C — modules/aifoundryproject/ refactor (Cognitive Services account/projects child)

- [X] T-C017-011 Rewrite [modules/aifoundryproject/main.tf](../../modules/aifoundryproject/main.tf) per [plan.md §6](plan.md): switch the `azapi_resource` type to `Microsoft.CognitiveServices/accounts/projects@2025-09-01`, set `parent_id = var.parent_account_id`, remove the `location` argument (inherited from the parent account), set the body to `{identity: {type: "SystemAssigned"}, properties: {displayName: var.canonical_name, description: "Foundry project ${var.canonical_name}"}}`, and omit top-level `tags` (the child inherits from the parent account). Keep the `azurerm_monitor_diagnostic_setting` block referencing `azapi_resource.this.id`. (FR-026 / C-017)
- [X] T-C017-012 Edit [modules/aifoundryproject/variables.tf](../../modules/aifoundryproject/variables.tf) per [plan.md §7](plan.md) + analyze BLOCKER B1: rename `hub_resource_id` → `parent_account_id`, tighten the validation regex to `^/subscriptions/.+/providers/Microsoft\.CognitiveServices/accounts/[^/]+$`, update the `error_message` to cite C-017 / FR-026, AND remove `variable "location"` and `variable "tags"` entirely (the project inherits both from the parent account in the new RP). (FR-026 / C-017)
- [X] T-C017-013 Edit [modules/aifoundryproject/locals.tf](../../modules/aifoundryproject/locals.tf) per [plan.md §8](plan.md): drop the legacy `public_network_access` default; the file may become empty (acceptable — leave a single-line comment or delete contents). (FR-026 / C-017)
- [X] T-C017-014 Refresh [modules/aifoundryproject/README.md](../../modules/aifoundryproject/README.md) per [plan.md §9](plan.md): document the new `parent_account_id` input, the renamed-from-`hub_resource_id` migration note, and the C-017 / FR-026 rationale. (FR-026 / C-017)
- [X] T-C017-015 Edit every fixture under [modules/aifoundryproject/tests/](../../modules/aifoundryproject/tests/) per [plan.md §10](plan.md) + analyze MAJOR M3: rename `hub_resource_id = ...` → `parent_account_id = ...` with a valid Cognitive Services account resource-ID string in every positive fixture, AND delete the `location = ...` and `tags = {...}` lines from every fixture's `variables {}` block (those variables are removed by T-C017-012). The negative regex test must assert the new regex from T-C017-012. (FR-026 / C-017)

### Phase C-017.D — terraform/services/ root-stack rewire

- [X] T-C017-016 Edit [terraform/services/main.tf](../../terraform/services/main.tf) per [plan.md §11](plan.md) + analyze BLOCKER B1: drop the `storage_account_id` and `key_vault_id` arguments from `module "aifoundry"`; on `module "aifoundry_project"`, rename `hub_resource_id` → `parent_account_id` (the value remains `values(module.aifoundry)[0].resource_id`) AND delete the `location = ...` and `tags = ...` argument lines (the wrapper no longer accepts them per T-C017-012). (FR-026 / C-017)
- [X] T-C017-017 Edit [terraform/services/check.tf](../../terraform/services/check.tf) per [plan.md §12](plan.md): delete the `check "aifoundry_requires_hub_deps"` block; rename `check "aifoundry_project_requires_hub"` → `check "aifoundry_project_requires_account"` and update its `error_message` to cite the new account dependency (C-017 / FR-026). (FR-026 / C-017)
- [X] T-C017-018 Edit [terraform/services/tests/_fixtures.tftest.hcl](../../terraform/services/tests/_fixtures.tftest.hcl) per [plan.md §13](plan.md): drop any KV/SA-only-for-old-check entries from fixtures that select `aifoundry`; ensure the remaining fixture continues to plan-green. (FR-026 / C-017)
- [X] T-C017-019 [P] Create [terraform/services/tests/reject_aifoundry_project_without_account.tftest.hcl](../../terraform/services/tests/reject_aifoundry_project_without_account.tftest.hcl) per [plan.md §14](plan.md), modelled on [terraform/services/tests/reject_apim_spoke.tftest.hcl](../../terraform/services/tests/reject_apim_spoke.tftest.hcl): include the same `mock_provider azurerm/azapi/modtm/random/time` + `override_data` for `data.terraform_remote_state.hub_log` boilerplate; a `plan` run that selects `aifoundry_project` without `aifoundry` and `expect_failures` the new `aifoundry_project_requires_account` check with the C-017 / FR-026 error message. (FR-026 / C-017)

### Phase C-017.E — Day-one tfvars shrink

- [X] T-C017-020 Edit [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json) per [plan.md §15](plan.md): replace the `services` array with `[{"type":"aifoundry","purpose":"main"},{"type":"aifoundry_project","purpose":"main"}]` (the legacy KV + SA entries are dropped — the account no longer needs them). (FR-026 / C-017)

### Phase C-017.F — Naming catalogue tightening

- [X] T-C017-021 Edit [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf) per [plan.md §16](plan.md): change `aifoundry_project.azure_max` from 64 to 32 (Cognitive Services project name limit). Run `terraform -chdir=modules/naming test` to confirm no regression. (FR-026 / C-017)

### Phase C-017.G — Verification gates (HARD)

- [X] T-C017-022 `terraform fmt -recursive` from repo root → no changes. (FR-026 / C-017)
- [X] T-C017-023 [P] `terraform -chdir=modules/naming test` → 100% pass (catalogue tightening must not regress). (FR-026 / C-017)
- [X] T-C017-024 [P] `terraform -chdir=modules/aifoundry test` → 100% pass (Cognitive Services account wrapper plan-green standalone). (FR-026 / C-017)
- [X] T-C017-025 [P] `terraform -chdir=modules/aifoundryproject test` → 100% pass (account/projects child wrapper plan-green standalone; new regex negative green). (FR-026 / C-017)
- [X] T-C017-026 `terraform -chdir=terraform/services test` → 100% pass (new `reject_aifoundry_project_without_account` test green; relocated fixtures green). (FR-026 / C-017)

### Phase C-017.H — Rollout

- [X] T-C017-027 Push branch, open PR against `master`, squash-merge, delete remote+local branch per CLAUDE.md autonomy rules. (FR-026 / C-017)
- [X] T-C017-028 `git checkout master && git pull --ff-only`; dispatch `gh workflow run deploy.yaml -f service=services -f tenant=sp01 -f environment=dev -f action=apply -f apply=true`. (FR-026 / C-017)
- [X] T-C017-029 Verify with `az resource list -g rg-svc-uc1-sp01-dev-swc-001 -o table` that exactly 2 resources are present: `Microsoft.CognitiveServices/accounts` (kind=AIServices) and `Microsoft.CognitiveServices/accounts/projects`. Confirm the account shows `properties.allowProjectManagement == true`. (FR-026 / C-017)

### Phase C-017.I — Analyze remediations (folded from /speckit.analyze)

- [X] T-C017-030 Fix spec ↔ plan filename drift (analyze MAJOR M1): edit the C-017 §4 block in [specs/006-services/spec.md](../../specs/006-services/spec.md) to rename the negative-test file from `aifoundry_project_requires_account.tftest.hcl` to `reject_aifoundry_project_without_account.tftest.hcl` (matches the existing `reject_*.tftest.hcl` directory convention used by plan.md §14 / T-C017-019). (FR-026 / C-017)
- [X] T-C017-031 Fix plan §5 wording drift (analyze MAJOR M2): edit the C-017 §5 line in [specs/006-services/plan.md](../../specs/006-services/plan.md) to remove the inaccurate "the existing 'missing storage_account_id' run is removed" phrase — the existing run is `empty_canonical_name_rejected` (kept verbatim) per T-C017-009. (FR-026 / C-017)
- [X] T-C017-032 Add `properties.publicNetworkAccess` reminder to T-C017-004 implementation (analyze MINOR m1) — covered by plan.md §1 verbatim; included here for implementer hygiene. (FR-026 / C-017)
- [X] T-C017-033 Remove now-unused `data "azurerm_subscription" "current"` from [modules/aifoundryproject/main.tf](../../modules/aifoundryproject/main.tf) once T-C017-011 swaps to `parent_id = var.parent_account_id` (analyze MINOR m4). (FR-026 / C-017)

## Phase C-018 — Foundry account private endpoint + private DNS (amendment)

> Delivers [spec.md C-018 / FR-027](../../specs/006-services/spec.md). Opt-in
> private endpoint for the `aifoundry` Cognitive Services account; defaults
> preserve C-017 behaviour. `[P]` = parallelisable (different files, no
> ordering dependency).

### Phase C-018.A — DNS catalogue

- [X] T-C018-001 Edit [modules/dnszones/catalogue.tf](../../modules/dnszones/catalogue.tf) per [plan.md §C-018.1](plan.md): add row `"aiservices" = "privatelink.services.ai.azure.com"` to `local.catalogue` (keep `cogsvc`, `openai`). (FR-027 / C-018)
- [X] T-C018-002 [P] Update any zone-count / catalogue-completeness assertion under [modules/dnszones/tests/](../../modules/dnszones/tests/) for the new `aiservices` row; run `terraform -chdir=modules/dnszones test` → green. (FR-027 / C-018)

### Phase C-018.B — aifoundry wrapper PE support

- [X] T-C018-003 Edit [modules/aifoundry/variables.tf](../../modules/aifoundry/variables.tf) per [plan.md §C-018.2](plan.md): add `private_endpoint_enabled` (bool, default `false`), `private_endpoint_subnet_id` (string, default `null`, regex validator for `…/subnets/<name>` when non-null), `private_dns_zone_ids` (list(string), default `[]`). (FR-027 / C-018)
- [X] T-C018-004 Edit [modules/aifoundry/locals.tf](../../modules/aifoundry/locals.tf) per [plan.md §C-018.3](plan.md): make `defaults.public_network_access` resolve to `"Disabled"` when `var.private_endpoint_enabled` else `"Enabled"` (overrides still win); add `pe_name = "pep-${var.canonical_name}"`. (FR-027 / C-018)
- [X] T-C018-005 Edit [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf) per [plan.md §C-018.4](plan.md): add count-gated `azurerm_private_endpoint.this` (subnet `var.private_endpoint_subnet_id`, `private_service_connection` with `subresource_names=["account"]` targeting `azapi_resource.this.id`, `private_dns_zone_group { name="default", private_dns_zone_ids=var.private_dns_zone_ids }`); add a `precondition` asserting `private_endpoint_enabled ⇒ subnet set && zones non-empty`. (FR-027 / C-018)
- [X] T-C018-006 [P] Edit [modules/aifoundry/outputs.tf](../../modules/aifoundry/outputs.tf): add `output "private_endpoint_id"` = `one(azurerm_private_endpoint.this[*].id)`. (FR-027 / C-018)
- [X] T-C018-007 [P] Update [modules/aifoundry/README.md](../../modules/aifoundry/README.md) documenting the PE inputs and the in-module `pep-${canonical_name}` naming deviation (engine `private_endpoint` row reserved for the generic follow-up). (FR-027 / C-018)

### Phase C-018.C — services stack wiring

- [X] T-C018-008 Edit [terraform/services/variables.tf](../../terraform/services/variables.tf) per [plan.md §C-018.6](plan.md): add `enable_aifoundry_private_endpoint` (bool, default `false`), `private_endpoint_subnet_role` (string, default `"development"`, validator on known spoke roles), `vnet_state_backend` + `dns_state_backend` (objects, default `null`) with a validator `enable ⇒ both backends non-null`. Leave the A4 `private_endpoints`/`diagnostic_settings` hard-fails UNCHANGED. (FR-027 / C-018)
- [X] T-C018-009 Create [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf) per [plan.md §C-018.7](plan.md): `local.aifoundry_pe_required`, two count-gated `data "terraform_remote_state"` (`vnet`, `dns`), `local.pe_subnet_id`, `local.pe_zone_ids` (keys `cogsvc`/`openai`/`aiservices`). (FR-027 / C-018)
- [X] T-C018-010 Edit [terraform/services/main.tf](../../terraform/services/main.tf) per [plan.md §C-018.8](plan.md): pass `private_endpoint_enabled`, `private_endpoint_subnet_id`, `private_dns_zone_ids` into `module.aifoundry`. (FR-027 / C-018)
- [X] T-C018-011 Edit [terraform/services/check.tf](../../terraform/services/check.tf) per [plan.md §C-018.9](plan.md): add `check "aifoundry_pe_requires_account"`. (FR-027 / C-018)

### Phase C-018.D — Day-one tfvars

- [X] T-C018-012 Edit [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json) per [plan.md §C-018.10](plan.md): set `enable_aifoundry_private_endpoint=true`, `private_endpoint_subnet_role="development"`, add `vnet_state_backend` (key `sp01/npd/vnet.tfstate`) + `dns_state_backend` (key `hub/prd/dns.tfstate`). (FR-027 / C-018)

### Phase C-018.E — Tests

- [X] T-C018-013 [P] Create [modules/aifoundry/tests/private_endpoint_positive.tftest.hcl](../../modules/aifoundry/tests/private_endpoint_positive.tftest.hcl): PE enabled emits `azurerm_private_endpoint.this` (group id `account`), DNS zone group, and `publicNetworkAccess="Disabled"`. (FR-027 / C-018)
- [X] T-C018-014 [P] Create [modules/aifoundry/tests/private_endpoint_negative.tftest.hcl](../../modules/aifoundry/tests/private_endpoint_negative.tftest.hcl): `private_endpoint_enabled=true` with null subnet hard-fails; malformed subnet id fails the regex. (FR-027 / C-018)
- [X] T-C018-015 [P] Create [terraform/services/tests/aifoundry_pe_happy.tftest.hcl](../../terraform/services/tests/aifoundry_pe_happy.tftest.hcl): `enable_aifoundry_private_endpoint=true` with `override_data` for `data.terraform_remote_state.vnet` + `.dns`; asserts subnet + three zone ids wired into `module.aifoundry`. (FR-027 / C-018)
- [X] T-C018-016 [P] Create [terraform/services/tests/reject_pe_without_aifoundry.tftest.hcl](../../terraform/services/tests/reject_pe_without_aifoundry.tftest.hcl): toggle on, no `aifoundry` selected ⇒ `check.aifoundry_pe_requires_account` fails. (FR-027 / C-018)

### Phase C-018.F — Verification gates (HARD)

- [X] T-C018-017 `terraform fmt -recursive` from repo root → no changes. (FR-027 / C-018)
- [X] T-C018-018 [P] `terraform -chdir=modules/dnszones test` → 100% pass. (FR-027 / C-018)
- [X] T-C018-019 [P] `terraform -chdir=modules/aifoundry test` → 100% pass (existing + new PE tests). (FR-027 / C-018)
- [X] T-C018-020 `terraform -chdir=terraform/services test` → 100% pass (existing C-016/C-017 fixtures unchanged + new PE tests). (FR-027 / C-018)

### Phase C-018.G — Rollout

- [X] T-C018-021 Push branch, open PR against `master`, squash-merge, delete remote+local branch per CLAUDE.md autonomy rules. (FR-027 / C-018)
- [X] T-C018-022 `git checkout master && git pull --ff-only`; apply hub DNS so the new zone exists: dispatch `deploy.yaml` for `service=dns tenant=hub environment=npd` then `environment=prd` (`apply=true`). (FR-027 / C-018)
- [X] T-C018-023 Dispatch `deploy.yaml` for `service=services tenant=sp01 environment=dev action=apply apply=true`. (FR-027 / C-018)
- [X] T-C018-024 Verify `aif-uc1-uc1-sp01-dev-swc-001` shows `properties.publicNetworkAccess="Disabled"` and exactly one private endpoint `pep-aif-uc1-uc1-sp01-dev-swc-001` in the `development` subnet with a DNS zone group spanning `cogsvc`/`openai`/`aiservices`. Restore the state-SA firewall if temp-opened. (FR-027 / C-018)

## Phase C-019 — Foundry Application Insights tracing (hub-LA anchored)

Amendment delivering [spec.md C-019 / FR-028](spec.md#clarifications-amendment-2026-06-01-foundry-application-insights-tracing). Opt-in, default-preserving. Mirrors the C-018 embedded pattern.

### Phase C-019.A — aifoundry wrapper App Insights support

- [X] T-C019-001 Edit [modules/aifoundry/variables.tf](../../modules/aifoundry/variables.tf) per [plan.md §C-019.1](plan.md): add `application_insights_enabled` (bool, default `false`). (FR-028 / C-019)
- [X] T-C019-002 Edit [modules/aifoundry/locals.tf](../../modules/aifoundry/locals.tf) per [plan.md §C-019.2](plan.md): add `appi_name = "appi-${var.canonical_name}"` and `defaults.application_insights_application_type = "web"`. (FR-028 / C-019)
- [X] T-C019-003 Edit [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf) per [plan.md §C-019.3](plan.md): add count-gated `azurerm_application_insights.tracing` (`workspace_id = var.shared_log_analytics_workspace_id`) and `azapi_resource.appinsights_connection` (`Microsoft.CognitiveServices/accounts/connections@2025-09-01`, name `appinsights`, parent the account, `category="AppInsights"`, `authType="ApiKey"`, `isSharedToAll=true`, `metadata.ResourceId`+`target`=appi id, connection string via `sensitive_body.properties.credentials.key`). (FR-028 / C-019)
- [X] T-C019-004 [P] Edit [modules/aifoundry/outputs.tf](../../modules/aifoundry/outputs.tf): add `application_insights_id` = `one(azurerm_application_insights.tracing[*].id)` and `application_insights_connection_id` = `one(azapi_resource.appinsights_connection[*].id)`. (FR-028 / C-019)
- [X] T-C019-005 [P] Update [modules/aifoundry/README.md](../../modules/aifoundry/README.md) documenting the App Insights input and the in-module `appi-${canonical_name}` naming deviation (engine `app_insights` row stays the standalone path). (FR-028 / C-019)

### Phase C-019.B — services stack wiring

- [X] T-C019-006 Edit [terraform/services/variables.tf](../../terraform/services/variables.tf) per [plan.md §C-019.5](plan.md): add `enable_aifoundry_application_insights` (bool, default `false`). (FR-028 / C-019)
- [X] T-C019-007 Edit [terraform/services/main.tf](../../terraform/services/main.tf) per [plan.md §C-019.6](plan.md): pass `application_insights_enabled = var.enable_aifoundry_application_insights` into `module.aifoundry`. (FR-028 / C-019)
- [X] T-C019-008 Edit [terraform/services/check.tf](../../terraform/services/check.tf) per [plan.md §C-019.7](plan.md): add `check "aifoundry_appinsights_requires_account"`. (FR-028 / C-019)

### Phase C-019.C — Day-one tfvars

- [X] T-C019-009 Edit [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json) per [plan.md §C-019.8](plan.md): set `enable_aifoundry_application_insights=true`. (FR-028 / C-019)

### Phase C-019.D — Tests

- [X] T-C019-010 [P] Create [modules/aifoundry/tests/application_insights_positive.tftest.hcl](../../modules/aifoundry/tests/application_insights_positive.tftest.hcl): enabled emits one `azurerm_application_insights.tracing` (`workspace_id`=supplied hub LA) and one `azapi_resource.appinsights_connection` named `appinsights` parented by the account. (FR-028 / C-019)
- [X] T-C019-011 [P] Create [modules/aifoundry/tests/application_insights_negative.tftest.hcl](../../modules/aifoundry/tests/application_insights_negative.tftest.hcl): default disabled emits zero App Insights and zero connection. (FR-028 / C-019)
- [X] T-C019-012 [P] Create [terraform/services/tests/aifoundry_appinsights_happy.tftest.hcl](../../terraform/services/tests/aifoundry_appinsights_happy.tftest.hcl): `enable_aifoundry_application_insights=true` wires `application_insights_enabled=true` into `module.aifoundry`. (FR-028 / C-019)
- [X] T-C019-013 [P] Create [terraform/services/tests/reject_appinsights_without_aifoundry.tftest.hcl](../../terraform/services/tests/reject_appinsights_without_aifoundry.tftest.hcl): toggle on, no `aifoundry` selected ⇒ `check.aifoundry_appinsights_requires_account` fails. (FR-028 / C-019)

### Phase C-019.E — Verification gates (HARD)

- [X] T-C019-014 `terraform fmt -recursive` from repo root → no changes. (FR-028 / C-019)
- [X] T-C019-015 [P] `terraform -chdir=modules/aifoundry test` → 100% pass (existing + new App Insights tests). (FR-028 / C-019)
- [X] T-C019-016 `terraform -chdir=terraform/services test` → 100% pass (existing fixtures unchanged + new App Insights tests). (FR-028 / C-019)

### Phase C-019.F — Rollout

- [X] T-C019-017 Push branch, open PR against `master`, squash-merge, delete remote+local branch per CLAUDE.md autonomy rules. (FR-028 / C-019)
- [X] T-C019-018 `git checkout master && git pull --ff-only`; apply the services stack (`service=services tenant=sp01 environment=dev action=apply apply=true`). (FR-028 / C-019)
- [X] T-C019-019 Verify `aif-uc1-uc1-sp01-dev-swc-001` has an `AppInsights` connection and the `appi-aif-uc1-uc1-sp01-dev-swc-001` component is workspace-based against the hub LA. Restore the state-SA firewall if temp-opened. (FR-028 / C-019)

## Phase C-020 / C-021 — Container registry (private endpoint) + Container Apps (internal env)

Amendment 2026-06-01. Delivers FR-029 + FR-030. `[P]` = parallel-safe.

### Phase C-020/21.A — Naming + network foundations

- [X] T-C021-001 Edit [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf) per [plan.md §C-020/C-021.1](plan.md): add `container_app_environment` row (`abbr="cae"`, `shape="hyphenated"`, `azure_max=32`, `level="top"`). (FR-030 / C-021)
- [X] T-C021-002 Edit [specs/001-naming-convention-engine/spec.md](../001-naming-convention-engine/spec.md) Naming Pattern Table: add the matching `container_app_environment` → `cae` row (keeps `us6_catalogue_completeness` + CI audit green). (FR-030 / C-021)
- [X] T-C021-003 Edit [modules/network/locals.tf](../../modules/network/locals.tf) per [plan.md §C-020/C-021.3](plan.md): add `container-apps` role to `role_catalogue` (`abbr3="cae"`, `needs_nsg=true`, `needs_route_table=false`, `delegation=["Microsoft.App/environments"]`). (FR-030 / C-021)
- [X] T-C021-004 Edit [variables/sp01/npd/vnet.tfvars.json](../../variables/sp01/npd/vnet.tfvars.json): add `"container-apps": "10.240.2.192/27"` to `subnets`. (FR-030 / C-021)

### Phase C-020.B — cntreg private endpoint

- [X] T-C020-001 Edit [modules/cntreg/variables.tf](../../modules/cntreg/variables.tf): add `private_endpoint_enabled` (bool, default false), `private_endpoint_subnet_id` (string, default null), `private_dns_zone_ids` (list(string), default []) with validators. (FR-029 / C-020)
- [X] T-C020-002 Edit [modules/cntreg/locals.tf](../../modules/cntreg/locals.tf): when `private_endpoint_enabled` force `sku="Premium"`; derive `pep-${var.canonical_name}`. (FR-029 / C-020)
- [X] T-C020-003 Edit [modules/cntreg/main.tf](../../modules/cntreg/main.tf): set `public_network_access_enabled=false` when enabled; add count-gated `azurerm_private_endpoint.this` (subresource `registry`, `private_dns_zone_group`) + `lifecycle.precondition` (subnet non-null, zone list non-empty). (FR-029 / C-020)
- [X] T-C020-004 Edit [modules/cntreg/outputs.tf](../../modules/cntreg/outputs.tf): add `private_endpoint_id` output. (FR-029 / C-020)

### Phase C-021.C — containerapps module (NEW)

- [X] T-C021-005 [P] Create [modules/containerapps/versions.tf](../../modules/containerapps/versions.tf) + [providers.tf](../../modules/containerapps/providers.tf) mirroring an existing wrapper. (FR-030 / C-021)
- [X] T-C021-006 [P] Create [modules/containerapps/variables.tf](../../modules/containerapps/variables.tf): `canonical_name`, `resource_group_name`, `location`, `tags`, `engine_record`, `overrides`, `shared_log_analytics_workspace_id`, `infrastructure_subnet_id`, `vnet_id`. (FR-030 / C-021)
- [X] T-C021-007 Create [modules/containerapps/locals.tf](../../modules/containerapps/locals.tf) + [main.tf](../../modules/containerapps/main.tf): `azurerm_container_app_environment` (internal, `internal_load_balancer_enabled=true`, hub LA, one `Consumption` workload profile) + `azurerm_private_dns_zone` (`=default_domain`), `azurerm_private_dns_a_record` (`*`→`static_ip_address`), `azurerm_private_dns_zone_virtual_network_link` to spoke VNet. (FR-030 / C-021)
- [X] T-C021-008 [P] Create [modules/containerapps/outputs.tf](../../modules/containerapps/outputs.tf) + [README.md](../../modules/containerapps/README.md). (FR-030 / C-021)

### Phase C-020/21.D — services stack wiring

- [X] T-C021-009 Edit [terraform/services/locals.tf](../../terraform/services/locals.tf): add `container_app_environment` to `v1_selectable_types` and `type_short` (`cae`). (FR-030 / C-021)
- [X] T-C020-005 Edit [terraform/services/variables.tf](../../terraform/services/variables.tf): add `enable_container_registry_private_endpoint` (bool, default false), `enable_container_apps` (bool, default false), `container_apps_subnet_role` (string, default `container-apps`, role-validated); add `container_app_environment` to the services type allowlist; broaden the `dns_state_backend`/`vnet_state_backend` non-null validation for the new toggles. (FR-029/FR-030 / C-020/C-021)
- [X] T-C020-006 Edit [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): generalise gate to `local.any_pe_required`; add `local.acr_pe_zone_ids`, `local.container_apps_subnet_id`, `local.spoke_vnet_id`. (FR-029/FR-030 / C-020/C-021)
- [X] T-C020-007 Edit [terraform/services/main.tf](../../terraform/services/main.tf): thread PE inputs into `module.container_registry`; add `module "container_app_environment"`. (FR-029/FR-030)
- [X] T-C020-008 Edit [terraform/services/check.tf](../../terraform/services/check.tf): add `check "acr_pe_requires_registry"` + `check "container_app_env_requires_subnet"`. (FR-029/FR-030 / C-020/C-021)

### Phase C-020/21.E — Day-one tfvars

- [X] T-C021-010 Edit [variables/sp01/dev/services.tfvars.json](../../variables/sp01/dev/services.tfvars.json): add `container_registry` + `container_app_environment` selections; set `enable_container_registry_private_endpoint=true` + `enable_container_apps=true`. (FR-029/FR-030 / C-020/C-021)

### Phase C-020/21.F — Tests

- [X] T-C020-009 [P] Create [modules/cntreg/tests/private_endpoint_positive.tftest.hcl](../../modules/cntreg/tests/private_endpoint_positive.tftest.hcl): enabled ⇒ Premium SKU, `public_network_access_enabled=false`, one PE subresource `registry` + acr zone. (FR-029 / C-020)
- [X] T-C020-010 [P] Create [modules/cntreg/tests/private_endpoint_negative.tftest.hcl](../../modules/cntreg/tests/private_endpoint_negative.tftest.hcl): default ⇒ Standard SKU, public, zero PE. (FR-029 / C-020)
- [X] T-C021-011 [P] Create [modules/containerapps/tests/internal_env_positive.tftest.hcl](../../modules/containerapps/tests/internal_env_positive.tftest.hcl): internal env (`internal_load_balancer_enabled=true`, subnet+hub LA wired) + private DNS zone + wildcard A + vnet link. (FR-030 / C-021)
- [X] T-C020-011 [P] Create [terraform/services/tests/acr_pe_happy.tftest.hcl](../../terraform/services/tests/acr_pe_happy.tftest.hcl). (FR-029 / C-020)
- [X] T-C020-012 [P] Create [terraform/services/tests/reject_acr_pe_without_registry.tftest.hcl](../../terraform/services/tests/reject_acr_pe_without_registry.tftest.hcl). (FR-029 / C-020)
- [X] T-C021-012 [P] Create [terraform/services/tests/container_apps_happy.tftest.hcl](../../terraform/services/tests/container_apps_happy.tftest.hcl). (FR-030 / C-021)
- [X] T-C021-013 [P] Create [terraform/services/tests/reject_container_apps_without_subnet.tftest.hcl](../../terraform/services/tests/reject_container_apps_without_subnet.tftest.hcl). (FR-030 / C-021)

### Phase C-020/21.G — Verification gates (HARD)

- [X] T-C021-014 `terraform fmt -recursive` from repo root → no changes. (FR-029/FR-030)
- [X] T-C021-015 [P] `terraform -chdir=modules/cntreg test` → 100% pass. (FR-029 / C-020)
- [X] T-C021-016 [P] `terraform -chdir=modules/containerapps test` → 100% pass. (FR-030 / C-021)
- [X] T-C021-017 [P] `terraform -chdir=modules/naming test` + `modules/network test` → 100% pass (new catalogue/role rows). (FR-030 / C-021)
- [X] T-C021-018 `terraform -chdir=terraform/services test` → 100% pass. (FR-029/FR-030)

### Phase C-020/21.H — Rollout

- [X] T-C021-019 Push branch, open PR against `master`, squash-merge, delete remote+local branch. (FR-029/FR-030)
- [X] T-C021-020 `git checkout master && git pull --ff-only`; apply the `sp01/npd` VNet (adds `container-apps` subnet), then `sp01/dev` services. (FR-029/FR-030)
- [X] T-C021-021 Verify ACR `publicNetworkAccess=Disabled` + Premium + PE, and the ACA internal env + private default-domain DNS zone. Restore the state-SA firewall if temp-opened. (FR-029/FR-030)

---

## Phase FR-031 — Foundry Hosted-Agent network injection (engine, default-off)

### FR-031.A — Module inputs & locals

- [ ] T-FR031-001 Add inputs to [modules/aifoundry/variables.tf](../../modules/aifoundry/variables.tf): `network_injection_enabled` (bool, default false); `agent_subnet_id`, `agent_storage_account_id`, `agent_cosmosdb_account_id`, `agent_search_service_id` (string, default null, full-resource-id regex, null-allowed); cross-field validation requiring all four non-null + `private_endpoint_enabled=true` when injection on. (FR-031 / C-022..C-025)
- [ ] T-FR031-002 Add locals to [modules/aifoundry/locals.tf](../../modules/aifoundry/locals.tf): `network_injection_enabled` flag, three connection names (`conn-storage-/conn-cosmos-/conn-search-${canonical_name}` truncated), and the `network_injections` list (empty when off). (FR-031 / C-025)

### FR-031.B — Module resources

- [ ] T-FR031-003 [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf): merge `networkInjections` into the account `azapi` body ONLY when enabled (empty ⇒ attribute omitted, day-one parity). (FR-031 step 1 / VC-2)
- [ ] T-FR031-004 [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf): three count-gated `azapi_resource` `Microsoft.CognitiveServices/accounts/connections@2025-09-01` for BYO Storage/Cosmos/Search. (FR-031 step 2 / VC-4 / C-025)
- [ ] T-FR031-005 [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf): one count-gated `azapi_resource` `.../capabilityHosts@2025-09-01` (`capabilityHostKind="Agents"`, `customerSubnet`, three connection-name lists), `depends_on` the connections. (FR-031 step 3 / VC-3 / C-026)
- [ ] T-FR031-006 [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf): `precondition` on the account resource enforcing FR-031 step 4 (injection ⇒ PE on + four ids present), naming the missing input. (FR-031 step 4)

### FR-031.C — Tests (plan-level, mocked, `-backend=false`)

- [ ] T-FR031-007 [P] `modules/aifoundry/tests/network_injection_positive.tftest.hcl` — toggle on + all inputs ⇒ plan ok; assert injection scenario/subnet, capability host, three connections, account `publicNetworkAccess="Disabled"`.
- [ ] T-FR031-008 [P] `modules/aifoundry/tests/network_injection_reject.tftest.hcl` — toggle on + missing BYO id (expect fail) AND toggle on + `private_endpoint_enabled=false` (expect fail).
- [ ] T-FR031-009 [P] `modules/aifoundry/tests/network_injection_default_off.tftest.hcl` — toggle unset ⇒ zero connections, zero capability hosts, body has no `networkInjections` (day-one parity).

### FR-031.D — Verification gates (HARD)

- [ ] T-FR031-010 `terraform fmt -recursive` from repo root → no changes. (FR-031)
- [ ] T-FR031-011 `terraform -chdir=modules/aifoundry test` → 100% pass. (FR-031)

### FR-031.E — Rollout

- [ ] T-FR031-012 Push branch, open PR against `master`, squash-merge, delete remote+local branch. **No live apply** — engine-only, default-off (C-022). (FR-031)

### CA-013 — Dependent feature program (tracked, NOT in this PR)

- [x] T-FR031-D2 (Feature) 006+001: new `cosmosdb` selectable type + `modules/cosmosdb/` (private-by-default, PE + `privatelink.documents.azure.com`) + `cosmos` naming row. (CA-013 #2 / VC-3/VC-4/VC-6) — **DONE, see Phase FR-032 below.**
- [x] T-FR031-D3 (Feature) 004-vnet: new `agents` subnet role delegated `Microsoft.App/environments`, dedicated /24, exclusive. (CA-013 #3 / VC-5) — **DONE, PR #31 (FR-226).**
- [ ] T-FR031-D4 (Feature) 102-sp01-npd-vnet: expand spoke to `10.240.2.0/23`, agent subnet `10.240.3.0/24`. (CA-013 #4 / VC-5)
- [x] T-FR031-D5 (Feature) 002-private-dns: add Cosmos `privatelink.documents.azure.com` zone. (CA-013 #5 / VC-6) — **RETIRED: zone already in catalogue (`cosmos-sql`); no-op (C-029).**
- [ ] T-FR031-D6 (Feature) 103-sp01-dev-services: flip toggle, select BYO trio, thread agent subnet, **document ACR public-access mandate exception**. (CA-013 #6 / VC-7)
- [ ] T-FR031-D7 (Operator-approved, destructive) Live recreate: delete+purge Foundry account + capability host BEFORE the VNet, re-apply with injection on. NOT executed by automation. (CA-013 / VC-1 / VC-8)

---

## Phase FR-032 — `cosmosdb` private-by-default selectable type (engine, additive)

### FR-032.A — Naming row (feature 001)

- [x] T-FR032-001 Add top-level row `"cosmosdb" = { abbr="cosmos", shape="hyphenated", azure_max=44, level="top" }` to [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf). (FR-032 / VF-3)
- [x] T-FR032-002 Add the `cosmosdb` row to the Naming Pattern Table in [specs/001-naming-convention-engine/spec.md](../001-naming-convention-engine/spec.md) (top-level section). (FR-032)
- [x] T-FR032-003 Add `"cosmosdb"` to the four hard-coded type lists in [modules/naming/tests/us6_catalogue_completeness.tftest.hcl](../../modules/naming/tests/us6_catalogue_completeness.tftest.hcl); bump top-level count 27→28. (FR-032)

### FR-032.B — Wrapper module `modules/cosmosdb/`

- [x] T-FR032-004 `modules/cosmosdb/versions.tf` — terraform ~>1.9, azurerm ~>4.0. (FR-021/FR-022)
- [x] T-FR032-005 `modules/cosmosdb/variables.tf` — canonical_name (≤44 regex), rg/location/tags, engine_record, overrides, `shared_log_analytics_workspace_id`, `diagnostic_settings_enabled` (default true), REQUIRED `private_endpoint_subnet_id` (full-subnet-id regex) + non-empty `private_dns_zone_ids`. (FR-032 steps 3/4)
- [x] T-FR032-006 `modules/cosmosdb/locals.tf` — private-only defaults (`Session`, `local_authentication_disabled=true`, no free tier, no auto-failover), `pe_name=pep-${canonical_name}`. (FR-032)
- [x] T-FR032-007 `modules/cosmosdb/main.tf` — `azurerm_cosmosdb_account` (`offer_type=Standard`, `kind=GlobalDocumentDB`, `public_network_access_enabled=false` ALWAYS, single geo_location); always-on `azurerm_private_endpoint` (`subresource_names=["Sql"]`, DNS zone group); count-gated diag → hub LA. (FR-032 steps 1-4 / VC-2)
- [x] T-FR032-008 `modules/cosmosdb/outputs.tf` — `resource_id`, `private_endpoint_id`. (FR-019)
- [x] T-FR032-009 [P] `modules/cosmosdb/tests/positive.tftest.hcl` — asserts public=false, local-auth disabled, GlobalDocumentDB, PE subnet/Sql/zone, diag→hub LA. (FR-032)
- [x] T-FR032-010 [P] `modules/cosmosdb/tests/negative.tftest.hcl` — rejects empty/uppercase name, malformed PE subnet, empty zone list. (FR-032)

### FR-032.C — Services-stack wiring

- [x] T-FR032-011 [terraform/services/locals.tf](../../terraform/services/locals.tf): add `cosmosdb` to `v1_selectable_types`; `type_short.cosmosdb="cos"`. (FR-032)
- [x] T-FR032-012 [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): `cosmosdb_selected`; include in `vnet_state_required`/`dns_state_required` gated on backend non-null; resolve `cosmosdb_pe_subnet_id` + `cosmosdb_pe_zone_ids` (`zone_ids["cosmos-sql"]`). (FR-032 / VF-1)
- [x] T-FR032-013 [terraform/services/main.tf](../../terraform/services/main.tf): `module "cosmosdb"` (for_each `type=="cosmosdb"`) wiring PE subnet + zone ids. (FR-032)
- [x] T-FR032-014 [terraform/services/variables.tf](../../terraform/services/variables.tf): add `cosmosdb` to `services[*].type` allow-list; `var.dns_state_backend` validation requiring both backends when `cosmosdb` selected. (FR-032 / C-028)
- [x] T-FR032-015 [terraform/services/check.tf](../../terraform/services/check.tf): `check "cosmosdb_requires_backends"`. (FR-032 / C-028)
- [x] T-FR032-016 `terraform/services/tests/cosmosdb_happy.tftest.hcl` — selecting `cosmosdb` resolves PE subnet + `cosmos-sql` zone; one module instance. (FR-032)

### FR-032.D — Verification gates (HARD)

- [x] T-FR032-017 `terraform fmt -recursive` from repo root → no changes. (FR-032)
- [x] T-FR032-018 `terraform -chdir=modules/cosmosdb test` → 7/7 pass. (FR-032)
- [x] T-FR032-019 `terraform -chdir=modules/naming test` → 36/36 pass. (FR-032)
- [x] T-FR032-020 `terraform -chdir=terraform/services test` → 15/15 pass. (FR-032)

### FR-032.E — Rollout

- [ ] T-FR032-021 Push branch, open PR against `master`, squash-merge, delete remote+local branch. **No live apply** — additive engine type, no instance selects `cosmosdb` (C-027). (FR-032)

---

## Phase FR-033 — services-stack Hosted-Agent network-injection passthrough (engine, default-off)

### FR-033.A — Stack variables

- [x] T-FR033-001 [terraform/services/variables.tf](../../terraform/services/variables.tf): new `enable_aifoundry_network_injection` (bool, default false; validation requires `enable_aifoundry_private_endpoint`) + `agent_subnet_role` (string, default `"agents"`, 13-role allow-list). (FR-033 / C-031)
- [x] T-FR033-002 [terraform/services/variables.tf](../../terraform/services/variables.tf): widen `private_endpoint_subnet_role` + `container_apps_subnet_role` allow-lists to 13 roles (add `agents`); add `vnet_state_backend` validation requiring it when injection on. (FR-033 / C-032)

### FR-033.B — Resolution & wiring

- [x] T-FR033-003 [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): `agent_injection_enabled` flag; add to `vnet_state_required`; resolve `agent_subnet_id` from `subnets[var.agent_subnet_role]`. (FR-033 step 1)
- [x] T-FR033-004 [terraform/services/main.tf](../../terraform/services/main.tf): `module "aifoundry"` block sets `network_injection_enabled`, `agent_subnet_id`, and three BYO inputs via `one([for k, v in module.<svc> : v.resource_id])` gated on the toggle. (FR-033 step 2 / C-033)
- [x] T-FR033-005 [terraform/services/check.tf](../../terraform/services/check.tf): `check "aifoundry_network_injection_prereqs"` (injection ⇒ private account + exactly one each of aifoundry/storage/cosmosdb/search). (FR-033 step 3)

### FR-033.C — Tests

- [x] T-FR033-006 `terraform/services/tests/agent_injection_happy.tftest.hcl` — toggle on + BYO trio + private account + vnet/dns stubs ⇒ `agent_subnet_id` resolves by the `agents` role, one instance each leg. (FR-033)

### FR-033.D — Verification gates (HARD)

- [x] T-FR033-007 `terraform fmt -recursive` → no changes. (FR-033)
- [x] T-FR033-008 `terraform -chdir=terraform/services test` → 16/16 pass. (FR-033)
- [x] T-FR033-009 `terraform -chdir=modules/aifoundry test` → 15/15 pass (module unchanged). (FR-033)

### FR-033.E — Rollout

- [ ] T-FR033-010 Push branch, open PR against `master`, squash-merge, delete remote+local branch. **No live apply** — engine-only, default-off (C-031). (FR-033)

---

## Phase FR-034 — storage account private endpoint (engine, opt-in, default-off)

### FR-034.A — Module

- [x] T-FR034-001 [modules/storage/variables.tf](../../modules/storage/variables.tf): `private_endpoint_enabled` (bool, default false) + `private_endpoint_subnet_id` (subnet-id regex) + `private_dns_zone_ids`. (FR-034 / C-035)
- [x] T-FR034-002 [modules/storage/locals.tf](../../modules/storage/locals.tf): `pe_name = "pep-${canonical_name}"`. (FR-034)
- [x] T-FR034-003 [modules/storage/main.tf](../../modules/storage/main.tf): `public_network_access_enabled = !private_endpoint_enabled`; count-gated `azurerm_private_endpoint` (subresource `blob` + DNS zone group + precondition). (FR-034 / C-036)
- [x] T-FR034-004 [modules/storage/outputs.tf](../../modules/storage/outputs.tf): `private_endpoint_id` (null when off). (FR-034)

### FR-034.B — Stack wiring

- [x] T-FR034-005 [terraform/services/variables.tf](../../terraform/services/variables.tf): `enable_storage_private_endpoint` (default false) + backend validation. (FR-034 / C-038)
- [x] T-FR034-006 [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): `storage_pe_required` gate + `storage_pe_subnet_id` + `storage_pe_zone_ids` (`blob` zone). (FR-034 / C-037)
- [x] T-FR034-007 [terraform/services/main.tf](../../terraform/services/main.tf): thread the three inputs into `module.storage`. (FR-034)
- [x] T-FR034-008 [terraform/services/check.tf](../../terraform/services/check.tf): `check "storage_pe_requires_storage"`. (FR-034 / C-038)

### FR-034.C — Tests

- [x] T-FR034-009 `modules/storage/tests/private_endpoint_{positive,negative}.tftest.hcl` + `terraform/services/tests/storage_pe_happy.tftest.hcl` — NEW. (FR-034)

### FR-034.D — Verification gates (HARD)

- [x] T-FR034-010 `terraform fmt -recursive` → no changes. (FR-034)
- [x] T-FR034-011 `terraform -chdir=modules/storage test` → 8/8 pass. (FR-034)
- [x] T-FR034-012 `terraform -chdir=terraform/services test` → 17/17 pass. (FR-034)

### FR-034.E — Rollout

- [ ] T-FR034-013 Push branch, open PR against `master`, squash-merge, delete remote+local branch. **No live apply** — engine-only, default-off (C-035). (FR-034)

---

## Phase FR-035 — AI Search private endpoint (engine, opt-in, default-off)

### FR-035.A — Module

- [x] T-FR035-001 [modules/search/variables.tf](../../modules/search/variables.tf): `private_endpoint_enabled` (bool, default false) + `private_endpoint_subnet_id` (subnet-id regex) + `private_dns_zone_ids`. (FR-035 / C-039)
- [x] T-FR035-002 [modules/search/locals.tf](../../modules/search/locals.tf): `pe_name = "pep-${canonical_name}"`. (FR-035)
- [x] T-FR035-003 [modules/search/main.tf](../../modules/search/main.tf): `public_network_access_enabled = !private_endpoint_enabled`; count-gated `azurerm_private_endpoint` (subresource `searchService` + DNS zone group + precondition). (FR-035 / C-040)
- [x] T-FR035-004 [modules/search/outputs.tf](../../modules/search/outputs.tf): `private_endpoint_id` (null when off). (FR-035)

### FR-035.B — Stack wiring

- [x] T-FR035-005 [terraform/services/variables.tf](../../terraform/services/variables.tf): `enable_search_private_endpoint` (default false) + backend validation. (FR-035 / C-042)
- [x] T-FR035-006 [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): `search_pe_required` gate + `search_pe_subnet_id` + `search_pe_zone_ids` (`search` zone). (FR-035 / C-041)
- [x] T-FR035-007 [terraform/services/main.tf](../../terraform/services/main.tf): thread the three inputs into `module.search`. (FR-035)
- [x] T-FR035-008 [terraform/services/check.tf](../../terraform/services/check.tf): `check "search_pe_requires_search"`. (FR-035 / C-042)

### FR-035.C — Tests

- [x] T-FR035-009 `modules/search/tests/private_endpoint_{positive,negative}.tftest.hcl` + `terraform/services/tests/search_pe_happy.tftest.hcl` — NEW. (FR-035)

### FR-035.D — Verification gates (HARD)

- [x] T-FR035-010 `terraform fmt -recursive` → no changes. (FR-035)
- [x] T-FR035-011 `terraform -chdir=modules/search test` → 8/8 pass. (FR-035)
- [x] T-FR035-012 `terraform -chdir=terraform/services test` → 18/18 pass. (FR-035)

### FR-035.E — Rollout

- [ ] T-FR035-013 Push branch, open PR against `master`, squash-merge, delete remote+local branch. **No live apply** — engine-only, default-off (C-039). (FR-035)

---

## Phase FR-040 — injected-account body alignment with Microsoft's proven reference (engine, injection-path only)

### FR-040.A — Module

- [ ] T-FR040-001 [modules/aifoundry/main.tf](../../modules/aifoundry/main.tf): make `azapi_resource.this.type` a `local.network_injection_enabled` ternary — `Microsoft.CognitiveServices/accounts@2025-04-01-preview` when injection ON, `…@2025-09-01` when OFF. (FR-040 / C-044 / VC-9)
- [ ] T-FR040-002 [modules/aifoundry/locals.tf](../../modules/aifoundry/locals.tf): extend the injection branch of `account_properties` with `networkAcls = { defaultAction = "Deny", virtualNetworkRules = [], ipRules = [], bypass = "AzureServices" }` and `disableLocalAuth = false`; non-injection branch unchanged. (FR-040 / C-045 / C-046 / VC-10 / VC-11)

### FR-040.B — Tests

- [ ] T-FR040-003 [modules/aifoundry/tests/network_injection_positive.tftest.hcl](../../modules/aifoundry/tests/network_injection_positive.tftest.hcl): assert `azapi_resource.this.type` ends `@2025-04-01-preview`, `body.properties.networkAcls.defaultAction == "Deny"`, `…networkAcls.bypass == "AzureServices"`, and `body.properties.disableLocalAuth == false`. (FR-040 / VC-9/10/11)
- [ ] T-FR040-004 [modules/aifoundry/tests/network_injection_default_off.tftest.hcl](../../modules/aifoundry/tests/network_injection_default_off.tftest.hcl): assert `azapi_resource.this.type` ends `@2025-09-01` and the body omits `networkAcls` + `disableLocalAuth` (day-one parity). (FR-040 / C-044)

### FR-040.C — Verification gates (HARD)

- [ ] T-FR040-005 `terraform fmt -recursive` → no changes. (FR-040)
- [ ] T-FR040-006 `terraform -chdir=modules/aifoundry test` → all pass (15 existing + new asserts). (FR-040)

### FR-040.D — Rollout

- [ ] T-FR040-007 Push branch, open PR against `master`, squash-merge, delete remote+local branch. Then purge orphan `aif-uc1-uc1-sp01-dev-swc-001` and re-dispatch the `103` `services` apply via the `deploy` workflow (never a local apply). (FR-040 / CA-013 #6)

---

## Phase FR-041 — private-by-default master switch (engine)

### FR-041.A — Variables

- [x] T-FR041-001 [terraform/services/variables.tf](../../terraform/services/variables.tf): add `private_by_default` (bool, default `true`). (FR-041 / C-048)
- [x] T-FR041-002 [terraform/services/variables.tf](../../terraform/services/variables.tf): change `enable_aifoundry_private_endpoint`, `enable_container_registry_private_endpoint`, `enable_storage_private_endpoint`, `enable_search_private_endpoint`, `enable_aifoundry_application_insights` to `optional(bool, null)`. (FR-041)
- [x] T-FR041-003 [terraform/services/variables.tf](../../terraform/services/variables.tf): add `enable_keyvault_private_endpoint` (`optional(bool, null)`); leave `enable_aifoundry_network_injection` as `bool` default `false`. (FR-041 / C-031 / VC-1)
- [x] T-FR041-004 [terraform/services/variables.tf](../../terraform/services/variables.tf): broaden the existing "PE requires both backends" preconditions to fire on the resolved locals (inherited-private also demands backends). (FR-041 / C-049)

### FR-041.B — Resolution + wiring

- [x] T-FR041-005 [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): resolve `aifoundry_pe_required`/`acr_pe_required`/`storage_pe_required`/`search_pe_required` via `coalesce(<explicit>, var.private_by_default)`; add `keyvault_pe_required` + `appinsights_enabled` the same way; extend `vnet_state_required`/`dns_state_required` with keyvault. (FR-041)
- [x] T-FR041-006 [terraform/services/data.vnetdns.tf](../../terraform/services/data.vnetdns.tf): add `keyvault_pe_subnet_id` (by `private_endpoint_subnet_role`) + `keyvault_pe_zone_ids = [ zone_ids["vault"] ]`. (FR-041 / C-050)
- [x] T-FR041-007 [terraform/services/main.tf](../../terraform/services/main.tf): switch storage/search/ACR/Foundry PE args + Foundry app-insights arg from `var.enable_*` to the resolved `local.*`; wire keyvault PE args. (FR-041)

### FR-041.C — Key Vault PE module

- [x] T-FR041-008 [modules/keyvault/variables.tf](../../modules/keyvault/variables.tf): add `private_endpoint_enabled` (bool, default false), `private_endpoint_subnet_id`, `private_dns_zone_ids` (mirror modules/storage). (FR-041 / C-050)
- [x] T-FR041-009 [modules/keyvault/locals.tf](../../modules/keyvault/locals.tf): add `pe_name = "pep-${var.canonical_name}"`. (FR-041)
- [x] T-FR041-010 [modules/keyvault/main.tf](../../modules/keyvault/main.tf): set `public_network_access_enabled` + `network_acls { default_action / bypass }` driven by `private_endpoint_enabled`; add count-gated `azurerm_private_endpoint` (subresource `vault`, zone group, lifecycle precondition). (FR-041 / C-050)

### FR-041.D — Telemetry internet flags

- [x] T-FR041-011 [modules/appinsights/main.tf](../../modules/appinsights/main.tf) + [modules/loganalytics](../../modules/loganalytics): add `internet_access_enabled` (bool, default true) gating `internet_ingestion_enabled`/`internet_query_enabled`; stack drives it from the master (FR-041 §2, AMPLS-deferred exception). (FR-041 / C-051)
- [x] T-FR041-012 [modules/aifoundry](../../modules/aifoundry): Foundry App Insights child honours the same internet flags when telemetry enabled. (FR-041 / FR-028)

### FR-041.E — Checks

- [x] T-FR041-013 [terraform/services/check.tf](../../terraform/services/check.tf): add `check "private_by_default_requires_backends"` + `check "keyvault_pe_requires_keyvault"`. (FR-041 / C-049 / VC-15)

### FR-041.F — Tests

- [x] T-FR041-014 `terraform/services/tests/private_by_default_on.tftest.hcl` (VC-12). (FR-041)
- [x] T-FR041-015 `terraform/services/tests/private_by_default_explicit_off.tftest.hcl` (VC-13). (FR-041)
- [x] T-FR041-016 `terraform/services/tests/private_by_default_master_off.tftest.hcl` (VC-14, parity). (FR-041 / C-052)
- [x] T-FR041-017 `terraform/services/tests/private_by_default_missing_backend.tftest.hcl` (VC-15). (FR-041)
- [x] T-FR041-018 `modules/keyvault/tests/private_endpoint_happy.tftest.hcl` (VC-16). (FR-041)
- [x] T-FR041-019 `modules/keyvault/tests/private_endpoint_default_off.tftest.hcl` (parity). (FR-041)

### FR-041.G — Verification gates (HARD)

- [x] T-FR041-020 `terraform fmt -recursive` → no changes. (FR-041)
- [x] T-FR041-021 `terraform -chdir=modules/keyvault test` → all pass. (FR-041)
- [x] T-FR041-022 `terraform -chdir=modules/appinsights test` → all pass. (FR-041)
- [x] T-FR041-023 `terraform -chdir=terraform/services test` → all pass. (FR-041)

### FR-041.H — Rollout

- [ ] T-FR041-024 Push branch, open PR against `master`, squash-merge, delete remote+local branch. Engine-only; live effect lands on the next `103` `services` plan via the `deploy` workflow (never a local apply). (FR-041)

---

## Phase FR-042 — Foundry private-endpoint dependency bundle (engine, guard-only)

### FR-042.A — Helper locals + check

- [x] T-FR042-001 [terraform/services/locals.tf](../../terraform/services/locals.tf): add `storage_selected`/`search_selected`/`keyvault_selected` (mirror `cosmosdb_selected`). (FR-042)
- [x] T-FR042-002 [terraform/services/check.tf](../../terraform/services/check.tf): add `check "aifoundry_private_requires_private_deps"` — when `local.aifoundry_pe_required` + an `aifoundry` is selected, every SELECTED storage/search/keyvault must have its resolved PE toggle true; list offenders. (FR-042 / C-053 / VC-18)

### FR-042.B — Tests

- [x] T-FR042-003 `terraform/services/tests/aifoundry_private_deps_consistent.tftest.hcl` (VC-17). (FR-042)
- [x] T-FR042-004 `terraform/services/tests/aifoundry_private_deps_public_storage.tftest.hcl` (VC-18). (FR-042)
- [x] T-FR042-005 `terraform/services/tests/aifoundry_private_deps_master_off.tftest.hcl` (VC-19). (FR-042)

### FR-042.C — Verification gates (HARD)

- [x] T-FR042-006 `terraform fmt -recursive` → no changes. (FR-042)
- [x] T-FR042-007 `terraform -chdir=terraform/services test` → all pass. (FR-042)

### FR-042.D — Rollout

- [x] T-FR042-008 Push branch, open PR against `master`, squash-merge, delete remote+local branch. Engine-only, guard-only; same `deploy` workflow path as FR-041 (never a local apply). (FR-042)
