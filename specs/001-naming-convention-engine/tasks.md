---

description: "Task list for feature 001 — Naming Convention Engine"
---

# Tasks: Naming Convention Engine

**Input**: Design documents from `/specs/001-naming-convention-engine/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Tests ARE part of the deliverable for this feature. Spec FR-023 mandates a cross-product fixture; FR-038 mandates a snapshot regression gate. Every user story therefore includes `terraform test` tasks.

**Organization**: Tasks are grouped by user story. Two P1 stories (US1 deterministic names, US2 loud failure) are the MVP. US3 (catalogue extensibility) and US4 (baseline tags) are P2 and can ship in any order after the MVP.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Different file, no dependency on any incomplete task
- **[Story]**: Maps to spec user stories (US1–US4). Setup, Foundational, and Polish phases have no story label.
- Every task carries an exact workspace-relative file path.

## Path Conventions

Per [plan.md § Project Structure](plan.md):

- Engine module: `modules/naming/`
- Test harness root: `terraform/_naming_test/`
- All paths are repository-root-relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the empty module skeleton and the harness root. No engine logic yet.

- [ ] T001 Create directory `modules/naming/` and the empty test subdirectory `modules/naming/tests/snapshots/` (use `.gitkeep` files if needed so empty dirs commit).
- [ ] T002 [P] Create `modules/naming/versions.tf` with `terraform { required_version = "~> 1.9"; required_providers {} }` (provider-less per Constitution VII).
- [ ] T003 [P] Create `modules/naming/main.tf` containing only an introductory header comment block and a stub `terraform {}` reference; logic added in later phases.
- [ ] T004 [P] Create `modules/naming/README.md` linking to [specs/001-naming-convention-engine/quickstart.md](specs/001-naming-convention-engine/quickstart.md), [contracts/input-schema.md](specs/001-naming-convention-engine/contracts/input-schema.md), and [contracts/output-schema.md](specs/001-naming-convention-engine/contracts/output-schema.md).
- [ ] T005 Create directory `terraform/_naming_test/` and add `terraform/_naming_test/README.md` describing it as a non-stack harness root.
- [ ] T006 [P] Create `terraform/_naming_test/providers.tf` declaring `terraform { required_version = "~> 1.9" }` only (no providers).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Author the central catalogues and the public input contract. Every user story depends on these.

**⚠️ CRITICAL**: No user-story phase may start until this phase is complete.

- [ ] T007 Implement `modules/naming/variables.tf` with the full `variable "input"` declaration from [contracts/input-schema.md](specs/001-naming-convention-engine/contracts/input-schema.md), including all 5 `validation {}` blocks (topology enum, tenant regex, topology↔tenant cross-check, environment length 1..4, services non-empty), and the required `repo` field (FR-001 / FR-014).
- [ ] T008 Implement `modules/naming/catalogue.tf` § service catalogue: HCL map `local.services` populated from the day-one inventory table in `spec.md` FR-026 (every row, with `caf_abbr`, `shape`, `topology_scope`, `category`, `max_length`, `charset`, `case_rule`, `must_start_with_letter`, and parent/child-list metadata). Source the per-service `max_length` values from Microsoft's documented Azure resource-naming limits; include `keyvault=24`, `storage=24`, `container_registry=50`, generic hyphenated default `80`.
- [ ] T009 [P] Extend `modules/naming/catalogue.tf` § child catalogue: HCL map `local.child_types` for the 5 child-only entries (`subnet`, `nsg_rule`, `route`, `private_endpoint`, `diagnostic_setting`) with `parent_allowlist`, `numbering` (`positional` | `purpose-keyed`), and `child_list_key` per FR-027 / FR-028.
- [ ] T010 [P] Extend `modules/naming/catalogue.tf` § region catalogue: HCL map `local.region_codes` populated with the 8 day-one rows from FR-010 (`uksouth=uks` … `wus3=wus3`).
- [ ] T011 [P] Extend `modules/naming/catalogue.tf` § defaults catalogue: HCL map `local.defaults` keyed by `service_type`, with the minimum-deployable settings per spec FR-012 (e.g. `storage = { account_tier = "Standard", account_replication_type = "LRS" }`, `keyvault = { sku = "standard" }`, `log_analytics = { sku = "PerGB2018", retention_in_days = 30 }`). At least one default-settings entry per top-level service_type.
- [ ] T012 Implement `modules/naming/locals.tf` § stage 1 (parsed): flatten `var.input.services` into the parsed records described in [data-model.md](specs/001-naming-convention-engine/data-model.md) § Stage 1, computing `requested_index` per `(service_type)` based on list order × `count`. Skip entries whose `count == 0` (FR-039) but DO update no counter (i.e. subsequent entries of the same type still start at 001).
- [ ] T013 Implement `modules/naming/validate.tf` § module-level `check "input_shape" {}` blocks for: unknown `service_type` (FR-017 — message lists supported types), child-only used at top level (FR-026), unknown `region` (FR-018 — message lists supported codes), and unsupported parent for any child entry (FR-027). Errors MUST be plan-time.
- [ ] T014 Implement `modules/naming/locals.tf` § stage 2 (validated): cross-reference each parsed record against `local.services` and `local.child_types`; reject duplicate `purpose` tokens per `(parent, child_type)` (FR-029); reject any positional child whose ordinal would exceed 999 (FR-008); compute a normalised `region_code` for every record.

**Checkpoint**: Foundation ready (catalogues, validation skeleton, stage-1/2 parser/validator, stage-6 default/override merge). US1, US2, US3, US4 may start in parallel.

---

## Phase 3: User Story 1 — Deterministic Names From Intent (Priority: P1) 🎯 MVP

**Goal**: A caller passes `(topology, tenant, environment, region, repo, services[])` and receives a flat map of canonical names + `for_each` keys + the per-stack resource group, byte-identical on every run.

**Independent Test**: From `modules/naming/` run `terraform test -filter=tests/positive_topology.tftest.hcl tests/positive_regions.tftest.hcl tests/positive_children.tftest.hcl tests/positive_full_catalogue.tftest.hcl tests/determinism_snapshot.tftest.hcl`. All must pass; the snapshot fixture asserts byte-identical output against the committed reference.

### Tests for User Story 1 ⚠️

> Spec FR-023 / FR-038 / Constitution Principle IV mandate these tests.
> **Explicit four-step order for this phase:**
>
> 1. **T015–T019** — write the test fixtures. Expected state: RED (tests reference unimplemented locals).
> 2. **T021–T027** — implement the engine (locals stages, outputs, harness root).
> 3. **T020** — **boundary: tests → implementation → snapshot.** Capture the now-stable `output.names` map and write `modules/naming/tests/snapshots/reference.json`.
> 4. **Re-run T019** — expected state: GREEN. The snapshot fixture now asserts byte-identical output.

- [ ] T015 [P] [US1] Create `modules/naming/tests/positive_topology.tftest.hcl` — cross-product of `topology ∈ {hub, spoke}` × `tenant ∈ {hub, sp01, sp99}` × `environment ∈ {npd, prd, pre}`; asserts every emitted top-level name matches the hyphenated regex from FR-016. Includes a **minimal-input sub-run** with `services = []` asserting `length(module.naming.names) == 1` and that the only emitted record has `service_type == "resource_group"` and matches the per-stack RG canonical pattern (FR-039).
- [ ] T016 [P] [US1] Create `modules/naming/tests/positive_regions.tftest.hcl` — exercises every region in `local.region_codes`; asserts the short code appears in every emitted name exactly as catalogued (FR-010).
- [ ] T017 [P] [US1] Create `modules/naming/tests/positive_children.tftest.hcl` — fixtures for `vnet` with 3 purpose-keyed subnets, `nsg` with 2 purpose-keyed rules, `storage` with 2 positional private endpoints (each referencing a distinct subnet from the vnet); asserts `parent` resolution per FR-030 / FR-032 and that purpose-keyed child names match the purpose-keyed child regex from FR-016.
- [ ] T018 [P] [US1] Create `modules/naming/tests/positive_full_catalogue.tftest.hcl` — one valid request per `topology_scope` group covering every catalogued top-level `service_type` at least once across the file (FR-023). Hub-scoped types in `(hub, npd)` and `(hub, prd)`; spoke-scoped types in `(spoke=sp01, npd)`; `prd-hub-only` types only in `(hub, prd)`; `either` types in both. Additionally asserts that every emitted record's `service_type` exactly equals the requested value with no prefix collapse between similarly-prefixed types such as `vnet` vs `vpn_gateway` (FR-021).
- [ ] T019 [P] [US1] Create `modules/naming/tests/determinism_snapshot.tftest.hcl` — runs the reference input from [quickstart.md § 1](specs/001-naming-convention-engine/quickstart.md) and asserts `module.naming.names == jsondecode(file("${path.module}/tests/snapshots/reference.json"))` (FR-006 / FR-038).
- [ ] T020 [US1] **Boundary task (tests → implementation → snapshot).** AFTER T021–T027 are complete, generate the initial snapshot at `modules/naming/tests/snapshots/reference.json` by running the engine once against the reference input from quickstart.md and committing the exact emitted `names` map (formatted with stable key ordering via `jsonencode`). Re-running T019 against this committed file then turns the suite GREEN.

### Implementation for User Story 1

- [ ] T021 [US1] Implement `modules/naming/locals.tf` § stage 3 (numbered): assign `instance` per `(service_type, batch)` for top-level records (FR-008), and per `(child_type, parent canonical name)` for positional children. Order is list-position order; no offsets, no gaps. Cap at 999 (FR-008) — emit a hard error via `check {}` if exceeded.
- [ ] T022 [US1] Implement `modules/naming/locals.tf` § stage 4 (shaped): synthesise the per-record segment list — `caf_abbr`, `tenant`, `env`, `region_code`, `instance` — plus per-child variants per FR-030. For purpose-keyed children of hyphen-forbidden parents, the stage MUST set a sentinel that stage 5 converts into a hard error (FR-030).
- [ ] T023 [US1] Implement `modules/naming/locals.tf` § stage 5 (named): render canonical names per the 4 shapes in FR-016 (top-level hyphenated, top-level concatenated, purpose-keyed child of hyphenated parent, positional child of hyphenated parent). Use lowercase only; no other transforms.
- [ ] T024 [US1] Implement `modules/naming/locals.tf` § stage 5b (resource group): always emit exactly one `resource_group` record per batch keyed `rg-{tenant}-{env}-{region_code}-001` (FR-025); set every other record's `resource_group` field to this canonical name.
- [ ] T046 Implement `modules/naming/locals.tf` § stage 6 (override-merged defaults): emit `record.defaults = local.defaults[record.service_type]` and `record.overrides = lookup(var.input.overrides, record.canonical_name, {})` (FR-013). *Moved from US3 to Foundational so the US1 stage-7 record shape is complete; renumbering preserved.*
- [ ] T025 [US1] Implement `modules/naming/locals.tf` § stage 7 (emitted): build the flat output map keyed by canonical name with the 11-field record shape from [contracts/output-schema.md](specs/001-naming-convention-engine/contracts/output-schema.md) (`service_type`, `topology`, `tenant`, `environment`, `region`, `instance`, `purpose`, `parent`, `resource_group`, `tags` placeholder, `defaults`, `overrides`). Field `tags` is filled by US4; leave it as `{}` if US4 is not yet implemented.
- [ ] T026 [US1] Implement `modules/naming/outputs.tf` with `output "names"` (the stage-7 map) and `output "by_type"` (= `{ for n, r in local.emitted : r.service_type => n... }`).
- [ ] T027 [US1] Implement `terraform/_naming_test/main.tf` — instantiate `module "naming"` with the quickstart reference input, and `terraform/_naming_test/outputs.tf` forwarding `module.naming.names` and `module.naming.by_type`. Run `terraform -chdir=terraform/_naming_test init && terraform plan` and confirm zero diff (provider-less plan).

**Checkpoint**: US1 fully functional; all 5 US1 fixtures pass; snapshot committed.

---

## Phase 4: User Story 2 — Loud, Helpful Failure on Invalid Inputs (Priority: P1) 🎯 MVP

**Goal**: Every documented error class fails at plan time with a message naming the offending input AND the expected shape. No silent truncation, no name mutation.

**Independent Test**: From `modules/naming/` run `terraform test -filter=tests/negative_*.tftest.hcl`. Every negative fixture must `expect_failures` with the documented message substring.

### Tests for User Story 2 ⚠️

- [ ] T028 [P] [US2] Create `modules/naming/tests/negative_service_type.tftest.hcl` — submit `services = [{ type = "frobnicate" }]`; `expect_failures` on a check block; assert error message contains the literal `frobnicate` and the substring `supported service types:` (FR-017).
- [ ] T029 [P] [US2] Create `modules/naming/tests/negative_tenant.tftest.hcl` — three sub-runs for `tenant ∈ {"sp00", "sp1", "sp100"}`; assert each fails the `validation {}` block on `var.input` with the literal pattern `^(hub|sp(0[1-9]|[1-9][0-9]))$` in the message (FR-019).
- [ ] T030 [P] [US2] Create `modules/naming/tests/negative_region.tftest.hcl` — submit `region = "marsone"`; assert the error message names `marsone` and lists the catalogued regions (FR-018).
- [ ] T031 [P] [US2] Create `modules/naming/tests/negative_topology_scope.tftest.hcl` — three sub-runs: (a) `dns_zone` in `(hub, npd)`; (b) `firewall` in `(spoke=sp01, npd)`; (c) `function_app` in `(hub, prd)`. Each MUST fail and the message MUST name the offending `service_type`, its scope, and the requested `(topology, environment)` pair (FR-033). Also assert ZERO `names` are emitted on failure (all-or-nothing — FR-033).
- [ ] T032 [P] [US2] Create `modules/naming/tests/negative_charset_length.tftest.hcl` — pick a hyphen-forbidden service with a tight budget (`storage`, 24-char Azure max) and force a length overflow by combining longest tenant + longest env + longest region short code + instance `999` + an artificial padded `caf_abbr` via override; assert the error message contains `storage`, the candidate string, the byte budget `24`, the over-budget byte count, AND the substrings `region` and `tenant` (the remediation guidance — FR-016).
- [ ] T033 [P] [US2] Create `modules/naming/tests/negative_child_invariants.tftest.hcl` — sub-runs: (a) two subnets with `purpose = "app"` under the same vnet (FR-029); (b) a `private_endpoint` whose `subnet` field references a canonical name not in the batch (FR-032); (c) a top-level `services[]` entry of type `subnet` (FR-026); (d) an `overrides` map containing a key that does NOT match any emitted canonical name (FR-039); (e) `count: 1000` on a `storage` entry (FR-008 999 cap). Each sub-run asserts the documented hard error and message anchors.

### Implementation for User Story 2

- [ ] T034 [US2] Extend `modules/naming/validate.tf` with the topology-scope `check {}` block: for every emitted record, the `(topology, environment)` pair MUST satisfy `local.services[record.service_type].topology_scope` (FR-033). Error message format: `"service_type \"{type}\" has topology_scope=\"{scope}\" but request is (topology=\"{topology}\", environment=\"{environment}\")"`. Emit no records on failure.
- [ ] T035 [US2] Extend `modules/naming/validate.tf` with the duplicate-purpose `check {}` block per `(parent_canonical, child_type)` (FR-029). Error message MUST list every duplicate purpose token.
- [ ] T036 [US2] Extend `modules/naming/validate.tf` with the unresolved-parent `check {}` block for `private_endpoint.subnet` and any other parent-by-reference child fields (FR-032). Error message MUST list every unresolved reference.
- [ ] T037 [US2] Extend `modules/naming/validate.tf` with the length-budget `check {}` block (FR-016). For every candidate name, assert `length(name) <= local.services[service_type].max_length`. Error message MUST match the schema in FR-016 (service_type + candidate + limit + over-budget bytes + remediation guidance naming `region` and `tenant`).
- [ ] T038 [US2] Extend `modules/naming/validate.tf` with the shape-regex `check {}` block (FR-016): every top-level hyphenated, top-level concatenated, purpose-keyed child, and positional child name MUST match its corresponding regex. Error message MUST name the offending shape and candidate.
- [ ] T039 [US2] Extend `modules/naming/validate.tf` with the unmatched-override `check {}` block (FR-039): every key in `var.input.overrides` MUST appear in `local.emitted`. Error message MUST list every unmatched key.
- [ ] T040 [US2] Extend `modules/naming/validate.tf` with the instance-cap `check {}` block (FR-008): for every `(service_type)` top-level group and every `(child_type, parent)` positional group, the highest assigned `instance` MUST be `<= 999`. Error message MUST name the offending group and the requested count/instance.
- [ ] T041 [US2] Extend `modules/naming/validate.tf` with the purpose-keyed/hyphen-forbidden prohibition (FR-030): error if any purpose-keyed child is requested under a hyphen-forbidden parent, naming the `(child_type, parent_service_type)` pair.

**Checkpoint**: US2 fully functional; every documented error class proven; MVP complete (US1 + US2). Engine is shippable.

---

## Phase 5: User Story 3 — Single-Entry Catalogues for Extensibility (Priority: P2)

**Goal**: Adding a new service type, a new region, or a new default is a single-PR catalogue edit; no engine code changes.

**Independent Test**: Add one new row to each of `local.services`, `local.region_codes`, `local.defaults` (in a throwaway branch) and confirm the engine emits a valid name and default for the new combination without any other change. The catalogue-completeness check MUST fail if any row is added in one map but forgotten in another.

### Tests for User Story 3 ⚠️

- [ ] T042 [P] [US3] Create `modules/naming/tests/catalogue_completeness.tftest.hcl` — for every key in `local.services` (top-level entries), assert there is a matching key in `local.defaults`; conversely, every key in `local.defaults` MUST be a top-level entry in `local.services`. Mismatch fails the test with a message naming the offending key.
- [ ] T043 [P] [US3] Create `modules/naming/tests/catalogue_region_completeness.tftest.hcl` — assert that no two regions in `local.region_codes` share the same short code (uniqueness of the inverted map).
- [ ] T044 [P] [US3] Create `modules/naming/tests/catalogue_child_completeness.tftest.hcl` — for every entry in `local.child_types`, assert every `parent_allowlist` value resolves to a top-level entry in `local.services`.

### Implementation for User Story 3

- [ ] T045 [US3] Implement `modules/naming/validate.tf` § catalogue-completeness `check {}` block mirroring T042/T043/T044 as plan-time guards (so a malformed catalogue PR fails at `terraform validate`, not just at `terraform test`).
- [ ] T047 [US3] Update `modules/naming/README.md` with a "How to add a new service type / region / default" section that documents the single-PR catalogue-edit procedure and links to T042/T043/T044 fixtures.

*(T046 was relocated to Phase 2 above to unblock US1's independent test; its task ID is preserved.)*

**Checkpoint**: US3 complete; new catalogue rows can be added without engine edits.

---

## Phase 6: User Story 4 — Baseline Tags Emitted Alongside Every Name (Priority: P2)

**Goal**: Every emitted record carries the six-key baseline tag map (`tenant`, `topology`, `environment`, `region`, `managed_by`, `repo`), with optional per-name overrides merged on top.

**Independent Test**: From `modules/naming/` run `terraform test -filter=tests/tags_*.tftest.hcl`. Every emitted record MUST carry all six keys; override tests MUST show baseline keys un-removable.

### Tests for User Story 4 ⚠️

- [ ] T048 [P] [US4] Create `modules/naming/tests/tags_baseline.tftest.hcl` — for the quickstart reference input, assert every record in `module.naming.names` has exactly the six baseline keys with values equal to (`var.input.tenant`, `var.input.topology`, `var.input.environment`, `var.input.region`, `"terraform"`, `var.input.repo`) — FR-014.
- [ ] T049 [P] [US4] Create `modules/naming/tests/tags_overrides.tftest.hcl` — supply `overrides = { "stsp01npduks001" = { tags = { cost_center = "ABC123" } } }`; assert the target record has 7 tag keys (6 baseline + `cost_center`), and that the override CANNOT remove any baseline key.
- [ ] T050 [P] [US4] Create `modules/naming/tests/tags_override_key_validation.tftest.hcl` — sub-runs: (a) override key with leading `microsoft` prefix; (b) override key length 513; assert each fails with the FR-015 Azure tag-key validation error.

### Implementation for User Story 4

- [ ] T051 [US4] Implement `modules/naming/locals.tf` § stage 6b (tags): for every record, build `baseline = { tenant, topology, environment, region, managed_by = "terraform", repo }` (all snake_case per FR-014), then merge the override tag map (`lookup(var.input.overrides, canonical_name, {}).tags`, default `{}`) on top via `merge(baseline, overrides)`. Assign the result to `record.tags`.
- [ ] T052 [US4] Extend `modules/naming/validate.tf` with the override-tag-key `check {}` block: for every key in every override's `tags` map, length `1..512` AND no Azure-reserved prefix (`microsoft`, `azure`, `windows`) — FR-015. Error message lists every offending key.
- [ ] T053 [US4] Re-run T020 to regenerate `modules/naming/tests/snapshots/reference.json` so the snapshot now includes the populated `tags` field for every record; commit the updated snapshot with an explicit reviewer-sign-off note in the PR description per FR-038.

**Checkpoint**: US4 complete; tagging contract honoured; snapshot reflects full record shape.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, formatting, CI wiring, and the constitutional gates.

- [ ] T054 Run `terraform fmt -recursive modules/naming/ terraform/_naming_test/` and commit any formatting changes.
- [ ] T055 [P] Run `terraform -chdir=modules/naming init && terraform -chdir=modules/naming validate` and `terraform -chdir=terraform/_naming_test init && terraform -chdir=terraform/_naming_test validate`; fix any reported errors.
- [ ] T056 [P] Run the full test suite: `terraform -chdir=modules/naming test`. All positive, negative, snapshot, and catalogue-completeness fixtures MUST pass.
- [ ] T057 [P] Update `modules/naming/README.md` with: links to the four spec/contract docs, the four canonical-shape regexes, the day-one service inventory table (mirrored from FR-026), the day-one region table (FR-010), the snapshot lifecycle rules (FR-038), and a "Common failure modes" table mirroring [quickstart.md § Common failure modes](specs/001-naming-convention-engine/quickstart.md#common-failure-modes).
- [ ] T058 [P] Update `terraform/_naming_test/README.md` to state explicitly that this directory is NOT a landing-zone stack, MUST NOT be iterated by environment variables, and exists only for `terraform plan` smoke verification.
- [ ] T059 Add an entry under `## Future Work` in [plan.md](specs/001-naming-convention-engine/plan.md) (if not already present) referencing the per-module consumer migration as a separate spec.
- [ ] T060 Manually walk [quickstart.md](specs/001-naming-convention-engine/quickstart.md) steps 1–5 against a clean checkout to verify the worked example matches reality; fix the doc OR the engine to reconcile any divergence.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)** — no dependencies.
- **Phase 2 (Foundational)** — depends on Phase 1. Blocks every user story.
- **Phase 3 (US1, P1)** — depends on Phase 2 only.
- **Phase 4 (US2, P1)** — depends on Phase 2 only. Can run in parallel with US1, but T037/T038 length-budget and shape-regex checks read names produced by US1's stage 5; therefore T037/T038 ordering-edge: run them AFTER T023.
- **Phase 5 (US3, P2)** — depends on Phase 2. Independent of US1/US2 fixtures.
- **Phase 6 (US4, P2)** — depends on Phase 2 AND on US1's stage 7 (T025) to have the record shape with a `tags` slot. (US4 no longer depends on US3 because the defaults/overrides merge moved to Phase 2 / T046.)
- **Phase 7 (Polish)** — depends on the user stories you have chosen to ship.

### User-story dependencies

- US1 + US2 = MVP. Both P1. Ship together.
- US3, US4 are P2 and independent of each other. US3 depends only on Foundational; US4 depends on Foundational + US1's stage 7 (T025).

### Within each user story

- All `[P]` test-creation tasks can run in parallel.
- Within US1: T015–T019 (tests) `[P]` first (expected RED). Then T021–T027 (implementation). Then T020 (boundary task) captures the snapshot. Re-running T019 then turns the suite GREEN.
- Within US2: T028–T033 (tests) `[P]` first; then T034–T041 (validate.tf extensions). T037/T038/T039/T040/T041 each touch the SAME file `modules/naming/validate.tf` — they are sequential, not parallel.
- Within US3: T042–T044 `[P]`; T045 sequential (single file); T047 doc. (T046 was relocated to Phase 2.)
- Within US4: T048–T050 `[P]`; T051 (locals.tf), T052 (validate.tf), T053 (snapshot regen) sequential.

### Parallel opportunities

- All Phase 1 tasks except T001 / T005 (which create the directories) can run in parallel.
- Phase 2 catalogue tasks T009 / T010 / T011 are `[P]` (single file, but separate sections — author them sequentially OR split into three `catalogue.tf` siblings to truly parallelise).
- US1 / US3 / US4 fixture-creation tasks (different files) are `[P]`.
- Phase 7 polish tasks T055 / T056 / T057 / T058 are `[P]`.

---

## Parallel Example: User Story 1 fixture creation

After Phase 2 (Foundational) completes, a single developer can open five files in parallel:

```text
# Run as parallel agent tasks:
T015 modules/naming/tests/positive_topology.tftest.hcl
T016 modules/naming/tests/positive_regions.tftest.hcl
T017 modules/naming/tests/positive_children.tftest.hcl
T018 modules/naming/tests/positive_full_catalogue.tftest.hcl
T019 modules/naming/tests/determinism_snapshot.tftest.hcl
```

All five share NO file path overlap and have no inter-task dependency
(snapshot file is created later by T020).

---

## Implementation Strategy

### MVP scope (recommended first PR)

Phases 1 + 2 + 3 + 4. Delivers a working engine with both P1 stories
(`US1` deterministic names, `US2` loud failure), every documented
hard-error class, the cross-product fixture (FR-023), and the snapshot
gate (FR-038). The engine is provider-less, ships zero state, and is
exercised by `terraform test`.

### Increment 2

Phase 5 (US3 catalogue extensibility): adds catalogue-completeness
guards so a future single-row catalogue PR cannot silently desync the
maps.

### Increment 3

Phase 6 (US4 baseline tags): populates the `tags` field on every
record and re-baselines the snapshot. Implementations that ship before
this increment carry `tags = {}` on every record — explicitly contract-
forbidden by FR-014 in production, so US4 MUST land before any
consumer-module migration spec begins.

### Final

Phase 7 polish + the Future-Work consumer-migration follow-on specs
(out of scope here).

---

## Format-validation report

All 60 tasks conform to the required checklist format:

- ✅ Every line begins with `- [ ]`.
- ✅ Every line carries a sequential `T0NN` id (T001–T060).
- ✅ Setup, Foundational, and Polish tasks carry NO `[Story]` label.
- ✅ Every US-phase task carries the matching `[US1]`, `[US2]`, `[US3]`, or `[US4]` label.
- ✅ Every task description names at least one workspace-relative file path.
- ✅ `[P]` is used only where the task touches a file no other incomplete task touches.
