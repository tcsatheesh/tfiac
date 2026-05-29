# Tasks: Naming Convention Engine

**Input**: Design documents from `/specs/001-naming-convention-engine/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/naming-engine.md, quickstart.md

**Tests**: INCLUDED. The plan mandates `terraform test` coverage; every invariant (INV-1 … INV-10) and success criterion (SC-001 … SC-004) MUST have at least one `*.tftest.hcl` assertion.

**Organization**: The spec is table-driven and has no narrative user stories. The four `Success Criteria` (SC-001 format, SC-002 length, SC-003 determinism, SC-004 baseline tags) plus the engine's capability surface are mapped to six prioritised stories:

| Story | Title                                                        | Maps to                |
|-------|--------------------------------------------------------------|------------------------|
| US1   | Generate format-valid top-level names (MVP)                  | SC-001, SC-002         |
| US2   | Emit baseline tags + merge `extra_tags`                      | SC-004                 |
| US3   | Deterministic output across input re-orderings               | SC-003                 |
| US4   | Child resources (subnet, nsg_rule, route, apim_api, bastion, firewall, private_endpoint, diagnostic_setting) | spec child rows |
| US5   | FQDN passthrough for `dns_zone` / `private_dns_zone`         | spec FQDN rows         |
| US6   | Spec↔catalogue consistency CI gate                           | research.md D6         |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different files, no dependency on incomplete tasks.
- **[Story]**: Story label (US1…US6) for story-phase tasks only. Setup / Foundational / Polish carry no story label.

## Path Conventions

- Engine module: [modules/naming/](../../modules/naming/)
- Tests: [modules/naming/tests/](../../modules/naming/tests/)
- Example consumer: [terraform/_examples/naming/](../../terraform/_examples/naming/)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the module skeleton, version pin, and example-consumer skeleton.

- [ ] T001 Create directory layout `modules/naming/{catalogue,tests}/` and `terraform/_examples/naming/` per plan.md "Project Structure"
- [ ] T002 Create [modules/naming/main.tf](../../modules/naming/main.tf) with engine-version comment header (`# engine: 0.1.0`) and a `terraform { required_version = "~> 1.9" }` block; declare NO `required_providers` (engine has none). Also create [modules/naming/providers.tf](../../modules/naming/providers.tf) as an empty file with a single comment explaining the engine intentionally declares no providers (satisfies Constitution Principle VI's module-layout requirement)
- [ ] T003 [P] Create empty stub files [modules/naming/variables.tf](../../modules/naming/variables.tf), [modules/naming/locals.tf](../../modules/naming/locals.tf), [modules/naming/outputs.tf](../../modules/naming/outputs.tf) so subsequent tasks can edit in parallel
- [ ] T004 [P] Add a `.terraform-version` (`1.9.x`) and a minimal `README.md` in [modules/naming/](../../modules/naming/) pointing at the spec and contract
- [ ] T005 [P] Create [terraform/_examples/naming/providers.tf](../../terraform/_examples/naming/providers.tf) with `terraform { required_version = "~> 1.9" }` only (engine consumer doesn't need AzureRM for the example)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Catalogues, variable declarations, and validation scaffolding that EVERY story depends on. No story work may start until this phase is complete.

**⚠️ CRITICAL**: Catalogues are the engine's single source of truth (Constitution principle V); they must exist before any naming, tagging, or test code is written.

- [ ] T006 Populate the service catalogue in [modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf): `locals { services = { ... } }` with all 27 top-level rows + 8 child rows from spec.md "Naming Pattern Table", each carrying `abbr`, `shape` (`hyphenated`/`concatenated`/`rg_hyphenated`/`fqdn`/`child_purpose`/`singleton`/`positional`), `azure_max`, `level` (`top`/`child`), and `parent_type` for children
- [ ] T007 [P] Populate the region catalogue in [modules/naming/catalogue/regions.tf](../../modules/naming/catalogue/regions.tf): `locals { regions = { uks = "uksouth", weu = "westeurope", eus2 = "eastus2", ... } }` — minimum set drawn from existing `temp/*.yaml` stack files
- [ ] T008 Declare `variable "input"` in [modules/naming/variables.tf](../../modules/naming/variables.tf) with the object type from data-model.md and one `validation` block per field (regexes from spec.md "Inputs" table); `repo` regex `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` (case-preserving — sole exception to the lowercase-only rule), max 256
- [ ] T009 [P] Declare `variable "services"` in [modules/naming/variables.tf](../../modules/naming/variables.tf) as `list(object({...}))` per data-model.md, with per-element `validation` for `key` regex `^[a-z0-9]{1,16}$` and `service_purpose` regex `^[a-z0-9]{3}$`
- [ ] T010 [P] Declare `variable "children"` in [modules/naming/variables.tf](../../modules/naming/variables.tf) per data-model.md, with `validation` for `child_purpose` regex `^[a-z0-9]{3,7}$` and `key` regex `^[a-z0-9]{1,16}$`
- [ ] T011 [P] Declare `variable "extra_tags"` in [modules/naming/variables.tf](../../modules/naming/variables.tf) as `map(string)` with `default = {}` and a `validation` block enforcing key ≤ 512 chars / value ≤ 256 chars
- [ ] T012 In [modules/naming/locals.tf](../../modules/naming/locals.tf) add the region cross-check (INV-10) and baseline-tag-collision check (INV-8) as `precondition` blocks on a dummy `terraform_data` resource (the standard 1.9 idiom for cross-variable assertions)
- [ ] T013 [P] Create [modules/naming/tests/_fixtures.tftest.hcl](../../modules/naming/tests/_fixtures.tftest.hcl) holding shared `variables { ... }` blocks (a valid `input`, sample `services`, sample `children`) reused by other test files
- [ ] T014 Bootstrap [modules/naming/tests/foundational.tftest.hcl](../../modules/naming/tests/foundational.tftest.hcl) that runs `terraform init -backend=false` implicitly and asserts the catalogues are non-empty and contain expected keys (`resource_group`, `storage`, `keyvault`, `subnet`, `private_endpoint`); guards against accidental catalogue regressions
- [ ] T014a [P] Create [modules/naming/tests/foundational_unknown_region.tftest.hcl](../../modules/naming/tests/foundational_unknown_region.tftest.hcl) with `expect_failures` asserting `var.input.region = "xyz"` (not in `local.regions`) triggers INV-10

**Checkpoint**: `terraform test` in `modules/naming/` runs and the foundational test passes. Stories may now proceed in parallel.

---

## Phase 3: User Story 1 — Generate format-valid top-level names (Priority: P1) 🎯 MVP

**Goal**: Given a valid `input` + `services` list, emit a `names` output where every key is a canonical Azure name that (a) matches its `service_type`'s format from the spec table and (b) fits within `azure_max`.

**Independent Test**: Pass one entry of every top-level `service_type` (resource_group, vnet, storage, keyvault, ...) and assert each resulting key matches the expected regex and length.

### Tests for User Story 1 (write FIRST, must fail before implementation)

- [ ] T015 [P] [US1] Create [modules/naming/tests/us1_format.tftest.hcl](../../modules/naming/tests/us1_format.tftest.hcl) with one `run` block per `shape` (`hyphenated`, `concatenated`, `rg_hyphenated`), asserting the emitted key matches the regex implied by the shape and that `output.names[key].azure_max` equals the catalogue value
- [ ] T016 [P] [US1] Create [modules/naming/tests/us1_overflow.tftest.hcl](../../modules/naming/tests/us1_overflow.tftest.hcl) using `expect_failures = [output.names]` with deliberately over-wide inputs (e.g. `usecase = "uc99"` + `service_purpose = "kvx"` driving a `storage` entry to >24 chars) to prove INV-6 fires
- [ ] T017 [P] [US1] Create [modules/naming/tests/us1_unknown_type.tftest.hcl](../../modules/naming/tests/us1_unknown_type.tftest.hcl) with `expect_failures` asserting an unknown `service_type` ("widget") triggers INV-1
- [ ] T018 [P] [US1] Create [modules/naming/tests/us1_rg_shape.tftest.hcl](../../modules/naming/tests/us1_rg_shape.tftest.hcl) with `expect_failures` for (a) RG entry that supplies `service_purpose` and (b) non-RG entry missing `service_purpose` (INV-4)
- [ ] T018a [P] [US1] Create [modules/naming/tests/us1_duplicate_key.tftest.hcl](../../modules/naming/tests/us1_duplicate_key.tftest.hcl) with `expect_failures` asserting two entries sharing `(service_type, service_purpose, key)` triggers INV-2
- [ ] T018b [P] [US1] Create [modules/naming/tests/us1_instance_overflow.tftest.hcl](../../modules/naming/tests/us1_instance_overflow.tftest.hcl) with `expect_failures` asserting >999 entries in a single `(service_type, service_purpose)` group triggers INV-3

### Implementation for User Story 1

- [ ] T019 [US1] In [modules/naming/locals.tf](../../modules/naming/locals.tf) add `local.numbered_services` — sort `var.services` by `(service_type, service_purpose, key)`, group by `(service_type, service_purpose)`, assign `instance = format("%03d", n+1)`; add a `precondition` enforcing INV-1 (unknown service_type), INV-2 (duplicate key), INV-3 (>999), INV-4 (RG shape)
- [ ] T020 [US1] In [modules/naming/locals.tf](../../modules/naming/locals.tf) add `local.top_level_names` — a map keyed by canonical name produced by a `for` expression that selects the format string from `local.services[entry.service_type].shape` and interpolates `{abbr}-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` (hyphenated), the concatenated variant, or the RG variant
- [ ] T021 [US1] In [modules/naming/outputs.tf](../../modules/naming/outputs.tf) declare `output "names"` as the union of top-level and (later) child maps, with a `precondition` re-asserting `length(key) <= each.value.azure_max` (INV-6) and `regexall(...)` shape match (INV-7)
- [ ] T022 [US1] Wire the engine-version constant into [modules/naming/outputs.tf](../../modules/naming/outputs.tf) as `output "engine_version" = "0.1.0"` (semver string, no `v` prefix). This output is declared in [contracts/naming-engine.md](contracts/naming-engine.md) and consumers MAY pin against it.

**Checkpoint**: `terraform test modules/naming` shows all US1 tests green; an example stack passing one entry per top-level service_type yields a valid map.

---

## Phase 4: User Story 2 — Baseline tags + extra_tags merging (Priority: P1)

**Goal**: Every entry in `output.names` carries the 8 baseline tag keys (`tenant`, `environment`, `region`, `managed_by`, `repo`, `usecase`, `stack_purpose`, `service_purpose`) with correct values; per-entry and stack-level `extra_tags` merge additively; baseline-key collisions fail loudly.

**Independent Test**: Pass `extra_tags = { cost_center = "x" }` plus a per-entry `extra_tags = { owner = "y" }`; assert the emitted tag map contains all 8 baseline keys + both extras with their correct values; then assert that `extra_tags = { environment = "z" }` fails the plan.

### Tests for User Story 2

- [ ] T023 [P] [US2] Create [modules/naming/tests/us2_baseline_tags.tftest.hcl](../../modules/naming/tests/us2_baseline_tags.tftest.hcl) asserting every entry in `output.names` has the 8 baseline keys with values matching the inputs (region tag is the full name from `local.regions`, not the short code)
- [ ] T024 [P] [US2] Create [modules/naming/tests/us2_extra_merge.tftest.hcl](../../modules/naming/tests/us2_extra_merge.tftest.hcl) asserting stack-level and per-entry `extra_tags` both appear; per-entry overrides stack-level for the same non-baseline key
- [ ] T025 [P] [US2] Create [modules/naming/tests/us2_baseline_collision.tftest.hcl](../../modules/naming/tests/us2_baseline_collision.tftest.hcl) with `expect_failures` proving that `extra_tags = { environment = "x" }` triggers INV-8
- [ ] T026 [P] [US2] Create [modules/naming/tests/us2_tag_length.tftest.hcl](../../modules/naming/tests/us2_tag_length.tftest.hcl) with `expect_failures` for a value >256 chars (INV-9)
- [ ] T027 [P] [US2] Create [modules/naming/tests/us2_rg_tag.tftest.hcl](../../modules/naming/tests/us2_rg_tag.tftest.hcl) asserting RG entries' `service_purpose` tag is filled with the entry's `stack_purpose` (not blank)

### Implementation for User Story 2

- [ ] T028 [US2] In [modules/naming/locals.tf](../../modules/naming/locals.tf) add `local.baseline_tags(entry)` builder — a `for` expression producing the 8-key tag map per entry, reading the full region name via `local.regions[var.input.region]`
- [ ] T029 [US2] In [modules/naming/locals.tf](../../modules/naming/locals.tf) add `local.merged_tags(entry) = merge(local.baseline_tags(entry), var.extra_tags, entry.extra_tags)` and add a `precondition` asserting `keys(var.extra_tags)` and `keys(entry.extra_tags)` are disjoint from the baseline key set (INV-8)
- [ ] T030 [US2] Wire `tags = local.merged_tags(entry)` into the top-level map produced in T020; add a `postcondition` on `output "names"` asserting `length(k) <= 512` and `length(v) <= 256` for every emitted tag pair (INV-9)

**Checkpoint**: US1 + US2 tests green. The engine now emits a complete `{name, tags, azure_max, service_type}` object for every top-level entry.

---

## Phase 5: User Story 3 — Determinism (Priority: P2)

**Goal**: Identical inputs in any order produce byte-identical `output.names` (SC-003).

**Independent Test**: Run `terraform plan -out` twice with `services` re-ordered; `terraform output -json | diff` MUST be empty.

### Tests for User Story 3

- [ ] T031 [P] [US3] Create [modules/naming/tests/us3_determinism.tftest.hcl](../../modules/naming/tests/us3_determinism.tftest.hcl) with two `run` blocks supplying the same set of services in different list orders; assert `output.names` is `==` across both runs (key set, values, and `jsonencode(output.names)` byte-equal)
- [ ] T032 [P] [US3] Add a `run` block to [modules/naming/tests/us3_determinism.tftest.hcl](../../modules/naming/tests/us3_determinism.tftest.hcl) that re-orders `extra_tags` keys (HCL maps are unordered, but `jsonencode` must still be stable because keys sort alphabetically)

### Implementation for User Story 3

- [ ] T033 [US3] Audit `local.numbered_services` / `local.top_level_names` from Phase 3 to confirm every iteration goes through a sorted list, not `var.services` directly; replace any list-order-sensitive `for` with `[for e in sort(...) : ...]` patterns
- [ ] T034 [US3] Document the determinism contract in a comment block at the top of [modules/naming/locals.tf](../../modules/naming/locals.tf) listing the sort keys for `numbered_services` and `numbered_children`

**Checkpoint**: All three SC tests pass; re-ordering `services` does not change any byte of `output.names`.

---

## Phase 6: User Story 4 — Children (Priority: P2)

**Goal**: Support all 8 child rows (`subnet`, `nsg_rule`, `route`, `apim_api`, `vnet_bastion`, `vnet_firewall`, `private_endpoint`, `diagnostic_setting`); names use the parent's hyphenated tuple `{P}`; positional children number per `(child_type, parent, key)`; singletons fail loudly on duplicates.

**Independent Test**: Pass a `vnet` parent + two `subnet` children + one `vnet_bastion` + two `private_endpoint` children attached to a `storage` parent; assert all eight names follow the child shapes from the spec and that a second `vnet_bastion` triggers INV-5.

### Tests for User Story 4

- [ ] T035 [P] [US4] Create [modules/naming/tests/us4_child_purpose.tftest.hcl](../../modules/naming/tests/us4_child_purpose.tftest.hcl) covering `subnet`, `nsg_rule`, `route`, `apim_api`: assert name shape `{abbr}-{child_purpose}-{P}` where `{P}` is the parent's hyphenated tuple regardless of parent shape
- [ ] T036 [P] [US4] Create [modules/naming/tests/us4_singleton.tftest.hcl](../../modules/naming/tests/us4_singleton.tftest.hcl) covering `vnet_bastion` and `vnet_firewall`: assert shape `{abbr}-{P}`; add an `expect_failures` run for a duplicate (INV-5)
- [ ] T037 [P] [US4] Create [modules/naming/tests/us4_positional.tftest.hcl](../../modules/naming/tests/us4_positional.tftest.hcl) covering `private_endpoint` and `diagnostic_setting`: assert shape `{abbr}-{P}-{instance}` with `001`, `002`, ... per parent; assert a third entry yields `003`
- [ ] T038 [P] [US4] Create [modules/naming/tests/us4_parent_concatenated.tftest.hcl](../../modules/naming/tests/us4_parent_concatenated.tftest.hcl) attaching a `private_endpoint` to a `storage` parent (concatenated name) and asserting the child's `{P}` slot is the parent's **hyphenated** tuple (per spec "Child resources")

### Implementation for User Story 4

- [ ] T039 [US4] In [modules/naming/locals.tf](../../modules/naming/locals.tf) add `local.parent_tuple_by_key` — a map from each top-level entry's `key` to its hyphenated tuple `{abbr}-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` (or RG variant); this is what child names interpolate, not the canonical name
- [ ] T040 [US4] In [modules/naming/locals.tf](../../modules/naming/locals.tf) add `local.numbered_children` — sort `var.children` by `(service_type, parent_key, key)`; group by `(service_type, parent_key)`; assign positional `instance` for `positional` shapes; assert ≤1 for `singleton` shapes (INV-5); assert `parent_key` resolves to a known top-level entry and that `local.services[child].parent_type` matches the parent's `service_type` (`*` permits any)
- [ ] T041 [US4] In [modules/naming/locals.tf](../../modules/naming/locals.tf) build `local.child_names` map, dispatching on `shape` (`child_purpose` / `singleton` / `positional`) and pulling `{P}` from `local.parent_tuple_by_key`; merge into `local.all_names` consumed by `output "names"`
- [ ] T042 [US4] Extend `output "names"` map values with the optional `parent` field (the parent's canonical name) for child entries; re-verify INV-6/INV-7 postconditions cover child shapes

**Checkpoint**: All 8 child shapes produce correct names; singleton duplicates and unknown parents fail loudly.

---

## Phase 7: User Story 5 — FQDN passthrough (Priority: P3)

**Goal**: `dns_zone` and `private_dns_zone` entries use the caller-supplied FQDN verbatim as the canonical name; baseline tags still apply; FQDN regex enforced.

**Independent Test**: Pass `{ service_type = "private_dns_zone", key = "blob", service_purpose = "dns", fqdn = "privatelink.blob.core.windows.net" }` and assert the output map key equals the FQDN and carries the 8 baseline tags.

### Tests for User Story 5

- [ ] T043 [P] [US5] Create [modules/naming/tests/us5_fqdn.tftest.hcl](../../modules/naming/tests/us5_fqdn.tftest.hcl) asserting valid FQDN passes through verbatim as map key and tags are present
- [ ] T044 [P] [US5] Add an `expect_failures` `run` block in the same file for an invalid FQDN (uppercase, `>253` chars, or illegal chars)

### Implementation for User Story 5

- [ ] T045 [US5] Extend `variable "services"` in [modules/naming/variables.tf](../../modules/naming/variables.tf) with an optional `fqdn = optional(string)` field; add per-element `validation` requiring `fqdn` IFF `service_type` is `dns_zone` or `private_dns_zone`, with regex `^[a-z0-9.-]{1,253}$`
- [ ] T046 [US5] In [modules/naming/locals.tf](../../modules/naming/locals.tf) branch the name-composition `for` expression so `shape = "fqdn"` entries use `entry.fqdn` as the canonical name (skipping instance numbering); ensure these entries still receive baseline tags

**Checkpoint**: FQDN passthrough works; invalid FQDNs are rejected at plan time.

---

## Phase 8: User Story 6 — Spec ↔ catalogue consistency gate (Priority: P3)

**Goal**: CI fails when a `service_type` exists in the spec table but not in `catalogue/services.tf` (or vice versa). Closes research D6.

**Independent Test**: Manually remove a row from `catalogue/services.tf`; the CI script exits non-zero.

### Tests for User Story 6

- [ ] T047 [P] [US6] Create [modules/naming/tests/us6_catalogue_completeness.tftest.hcl](../../modules/naming/tests/us6_catalogue_completeness.tftest.hcl) asserting `local.services` contains every `service_type` listed in a hard-coded expected list (mirrors the spec table); fails loudly when a row is dropped
- [ ] T048 [P] [US6] Add an assertion in the same file that every catalogue row has the mandatory fields (`abbr`, `shape`, `level`) and that `level == "top"` rows have `azure_max`

### Implementation for User Story 6

- [ ] T049 [US6] Create [.specify/scripts/bash/check-naming-catalogue.sh](../../.specify/scripts/bash/check-naming-catalogue.sh) — a small shell+awk script that parses the spec.md tables (rows starting with `| \`` under `### Top-level resources` / `### Child resources`) and compares the `service_type` set against the keys present in `modules/naming/catalogue/services.tf`; exits non-zero on mismatch
- [ ] T050 [US6] Wire the script into a GitHub Actions workflow [.github/workflows/naming-catalogue.yml](../../.github/workflows/naming-catalogue.yml) that runs on PRs touching `specs/001-naming-convention-engine/spec.md` or `modules/naming/catalogue/**` and runs `terraform test` in `modules/naming/`

**Checkpoint**: Adding a row to spec.md without updating the catalogue (or vice versa) fails CI.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [ ] T051 [P] Create the example consumer in [terraform/_examples/naming/main.tf](../../terraform/_examples/naming/main.tf) using the realistic input set from [quickstart.md](quickstart.md) §1
- [ ] T052 [P] Create [terraform/_examples/naming/outputs.tf](../../terraform/_examples/naming/outputs.tf) re-exposing `module.names.names` so a `terraform output -json` snapshot can be diffed for SC-003
- [ ] T053 [P] Expand [modules/naming/README.md](../../modules/naming/README.md) with the quickstart from [quickstart.md](quickstart.md), the contract summary from [contracts/naming-engine.md](contracts/naming-engine.md), and a link back to spec.md
- [ ] T054 [P] Add a `# engine version` upgrade-checklist comment in [modules/naming/main.tf](../../modules/naming/main.tf) summarising the semver policy from [contracts/naming-engine.md](contracts/naming-engine.md) ("Backwards-compatibility policy")
- [ ] T055 Run [quickstart.md](quickstart.md) §3 manually: `terraform plan` twice with re-ordered services, `diff` the JSON, confirm empty (SC-003 manual gate)
- [ ] T056 Run `terraform test` from `modules/naming/` and capture the full output in the PR description; confirm every `*.tftest.hcl` file passes
- [ ] T057 [P] Add an entry to the repo-root `README.md` (if present) or create a top-level note pointing new contributors at `modules/naming/` as the canonical name/tag source per Constitution principle V

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** → no dependencies
- **Phase 2 (Foundational)** → depends on Phase 1; BLOCKS all stories
- **Phase 3 (US1)** → depends on Phase 2; provides the name-composition substrate other stories build on
- **Phase 4 (US2)** → depends on Phase 2 only in principle, but in practice runs after Phase 3 because both edit `output.names`
- **Phase 5 (US3)** → depends on Phase 3 (needs `numbered_services` to audit) and Phase 4 (so tagging is also covered by determinism check)
- **Phase 6 (US4)** → depends on Phase 3 (children reuse parent tuples) + Phase 4 (children must also carry baseline tags)
- **Phase 7 (US5)** → depends on Phase 2 + Phase 4 (passthrough names still need merged tags); independent of US4
- **Phase 8 (US6)** → depends on Phase 2 (catalogue must exist); independent of US1–US5
- **Phase 9 (Polish)** → depends on US1–US6 completion

### Within Each Story

- Tests (`*.tftest.hcl`) MUST be written and observed to fail before the corresponding `locals.tf` / `outputs.tf` change.
- Catalogue rows precede name composition; name composition precedes tagging; tagging precedes determinism checks.

### Parallel Opportunities

- T003, T004, T005 (Phase 1) — different files.
- T007, T009, T010, T011, T013 (Phase 2) — independent files / variables.
- T015–T018 (US1 tests) — separate `.tftest.hcl` files.
- T023–T027 (US2 tests) — separate files.
- T035–T038 (US4 tests) — separate files.
- US6 (Phase 8) can run in parallel with any story phase once Phase 2 is done.
- All Phase 9 [P] tasks — separate files.

---

## Parallel Example: User Story 1

```bash
# Write all US1 tests in parallel (they will FAIL until T019-T022 land):
Task: "Create modules/naming/tests/us1_format.tftest.hcl"
Task: "Create modules/naming/tests/us1_overflow.tftest.hcl"
Task: "Create modules/naming/tests/us1_unknown_type.tftest.hcl"
Task: "Create modules/naming/tests/us1_rg_shape.tftest.hcl"
```

---

## Implementation Strategy

### MVP First

1. Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1) → Phase 4 (US2).
2. After US2, the engine can name and tag any top-level resource the spec lists — sufficient for the existing `temp/_legacy/` modules to migrate.
3. STOP and validate: run quickstart §1–§3 against a real stack (e.g. `temp/hub.npd.vnet.yaml` shape).

### Incremental Delivery

- MVP (Phases 1–4): name + tag every top-level resource.
- Increment 1 (Phase 5): prove determinism, unblocks CI gates.
- Increment 2 (Phase 6): unlock subnets / NSG rules / private endpoints — required by spec 004-vnet and 005-services-stack.
- Increment 3 (Phase 7): unlock spec 002-private-dns-zones.
- Increment 4 (Phase 8): close the spec↔catalogue drift loop.
- Polish (Phase 9): docs, examples, repo-level signposting.

### Parallel Team Strategy

With multiple developers after Phase 2:

- Dev A: US1 → US3 (name composition + determinism)
- Dev B: US2 (tagging) — coordinates with Dev A on the shared `output "names"` shape
- Dev C: US4 (children) — starts when US1's `parent_tuple_by_key` is merged
- Dev D: US6 (CI gate) — fully independent of A/B/C

---

## Notes

- `[P]` tasks edit different files; the engine's main concentration of risk is `modules/naming/locals.tf`, so sequence Phase 3/4/5/6 edits to that file.
- Every test file lives under `modules/naming/tests/` and runs via `terraform test`; no Go, Python, or external test runner is introduced (research D2).
- The CI script in T049 is the only non-HCL artefact in this feature; keep it minimal (bash + awk).
- Commit after each task or logical group; every checkpoint is a sensible commit boundary.
