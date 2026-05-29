# Tasks: Private DNS Zones (prd-hub-only)

**Input**: Design documents from `/specs/002-private-dns-zones/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/dns-stack.md, quickstart.md

**Tests**: INCLUDED. FR-028, FR-030, FR-031, SC-005, and SC-007 explicitly mandate `terraform test`-based plan-time assertions and a committed snapshot fixture, so test tasks are first-class.

**Scope note**: US4 (legacy migration) is **N/A in v1** — the repository has no legacy `terraform/dns/` to migrate from. Phase 6 is therefore omitted; FR-032–FR-034 and SC-006 are reserved for a future feature.

**Organization**: Tasks are grouped by user story (US1–US3) so each story can be implemented, tested, and shipped as an independent increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete dependencies)
- **[Story]**: US1 / US2 / US3 / US4 — maps to a spec.md user story
- All paths are repository-relative

## Path Conventions

- Wrapper module: `modules/dnszones/`
- Root stack: `terraform/dns/`
- Stack inputs: `variables/hub/prd/dns.tfvars.json`
- Naming engine (already on master, NOT modified): `modules/naming/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Skeleton directory and version pins so every subsequent task has a place to land.

- [X] T001 Create directory skeletons: `modules/dnszones/`, `modules/dnszones/tests/`, `modules/dnszones/tests/fixtures/`, `terraform/dns/`, `terraform/dns/tests/`, `variables/hub/prd/`
- [X] T002 [P] Create `terraform/dns/versions.tf` pinning `terraform "~> 1.9"`, `azurerm "~> 4.0"`, `azapi "~> 2.4"`, `modtm "~> 0.3"`, `random "~> 3.5"`, `time "~> 0.13"` (research.md D2)
- [X] T003 [P] Create `terraform/dns/backend.tf` configuring `backend "azurerm"` with hard-coded `key = "hub/prd/dns.tfstate"`; other backend fields supplied via `-backend-config` at init (research.md D12)
- [X] T004 [P] Create `terraform/dns/providers.tf` with `provider "azurerm" { subscription_id = var.subscription_id; features {} }`
- [X] T005 [P] Create `modules/dnszones/providers.tf` declaring `required_providers` passthrough (`azurerm`, `azapi`, `modtm`, `random`, `time`) — NO provider blocks (Constitution VI)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Wrapper module skeleton + naming-engine plumbing + catalogue. EVERY user story depends on these existing before its tasks can start.

**CRITICAL**: Do not begin Phase 3 until Phase 2 is complete.

- [X] T006 Create `modules/dnszones/variables.tf` with the eight FR-014 inputs (`subscription_id`, `region`, `repo`, `topology`, `tenant`, `environment`, `custom_zones`, `disable_catalogue_zones`) and per-element `validation` blocks for `custom_zones` (FR-016 FQDN regex; DNS-INV-7) and uniqueness (`custom_zones` DNS-INV-4, `disable_catalogue_zones` DNS-INV-6)
- [X] T007 Create `modules/dnszones/catalogue.tf` defining `local.catalogue` map of 25 `(key, fqdn)` rows verbatim from spec FR-011 (DNS-INV-1, DNS-INV-2, FR-013)
- [X] T008 Create `modules/dnszones/locals.tf` deriving: (a) the engine input object (`local.input`), (b) `local.enabled_catalogue = { for k, v in local.catalogue : k => v if !contains(var.disable_catalogue_zones, k) }`, (c) `local.custom_map = { for f in var.custom_zones : f => f }`, (d) `local.effective_zones` combining both with `origin` discriminator (data-model.md Entity 4)
- [X] T009 Create `modules/dnszones/main.tf` instantiating `module "naming"` (source `../naming`, passing `local.input` plus the per-FQDN `services` list for `service_type = "private_dns_zone"`, one entry per effective zone using its FQDN as the `key` and `fqdn` field — research.md D3 uniform path)
- [X] T010 Extend `modules/dnszones/main.tf` with `module "rg"` calling `Azure/avm-res-resources-resourcegroup/azurerm` pinned `version = "~> 0.4"`, wiring `name` and `tags` from the engine's RG slot and `location = module.naming.region_full` (research.md D6, FR-009, FR-035)
- [X] T011 Create `modules/dnszones/check.tf` with a `terraform_data "assertions"` resource carrying preconditions for DNS-INV-1 (catalogue key uniqueness), DNS-INV-2 (catalogue FQDN uniqueness), DNS-INV-3 (custom-vs-catalogue shadowing; FR-017), DNS-INV-5 (disable subset; FR-018) — each with a message naming the offending value(s) (research.md D8, FR-031)
- [X] T012 Create `modules/dnszones/outputs.tf` declaring `zone_ids` (initially `{}` placeholder), `zone_names`, `resource_group_name`, `resource_group_id`, `naming` — with an output-level precondition asserting `keys(zone_ids) == keys(zone_names)` (DNS-INV-10)
- [X] T013 Create `terraform/dns/variables.tf` with the eight FR-014 inputs and `variable.validation` blocks enforcing DNS-INV-9: `var.topology == "hub"`, `var.environment == "prd"`, `var.region == "swc"` (FR-001, research.md D4)
- [X] T014 Create `terraform/dns/locals.tf` shaping the wrapper-module input object from `var.*`
- [X] T015 Create `terraform/dns/main.tf` calling `module "dnszones" { source = "../../modules/dnszones"; ... }` and adding a `check "subscription_match"` block asserting `var.subscription_id == data.azurerm_client_config.current.subscription_id` (FR-029, DNS-INV-8)
- [X] T016 Create `terraform/dns/outputs.tf` re-exporting `zone_ids`, `zone_names`, `resource_group_name`, `resource_group_id`, `naming` from the wrapper module (contracts/dns-stack.md)
- [X] T017 Create `variables/hub/prd/dns.tfvars.json` with the reference inputs (subscription placeholder `00000000-...`, `region=swc`, `topology=hub`, `tenant=hub`, `environment=prd`, empty `custom_zones`, empty `disable_catalogue_zones`) — quickstart.md §1
- [X] T018 Create `modules/dnszones/tests/_fixtures.tftest.hcl` defining the reference `variables` block and any common `run "setup"` blocks used by every later test (feature 001 pattern)
- [X] T019 [P] Run `terraform init -backend=false` in both `modules/dnszones/` and `terraform/dns/` and confirm `terraform validate` passes for the bare skeleton (gate before Phase 3)

**Checkpoint**: Wrapper compiles, root stack compiles, naming engine wired, catalogue defined, all four cross-cutting hard-fails (FR-001, FR-017, FR-018, FR-029) fire — user stories can now begin.

---

## Phase 3: User Story 1 — Spoke owner consumes zones without provisioning (Priority: P1) 🎯 MVP

**Goal**: A consumer reads `terraform_remote_state.dns.outputs.zone_ids[<key>]` for any of the 25 catalogue keys and gets a valid Azure resource ID; re-plan with unchanged inputs is zero-diff.

**Independent Test**: From a clean state apply with reference inputs → `output.zone_ids` is a 25-key map of non-empty IDs; `output.zone_names["blob"] == "privatelink.blob.core.windows.net"`; re-plan → 0/0/0 (spec US1 scenarios 1–4).

### Tests for User Story 1

- [X] T020 [P] [US1] Write `modules/dnszones/tests/catalogue_completeness.tftest.hcl` asserting `length(local.catalogue) == 25`, that every key matches `^[a-z][a-z0-9-]{1,15}$`, and that every value matches the FR-016 FQDN regex (DNS-INV-1/2, FR-012)
- [X] T021 [P] [US1] Write `modules/dnszones/tests/zone_keys_default.tftest.hcl` asserting with reference inputs that `keys(output.zone_ids) == sort(keys(local.catalogue))` and `length(output.zone_ids) == 25` (spec US1 scenario 1)
- [X] T022 [P] [US1] Write `modules/dnszones/tests/zone_name_blob.tftest.hcl` asserting `output.zone_names["blob"] == "privatelink.blob.core.windows.net"` (spec US1 scenario 2)
- [X] T023 [P] [US1] Write `modules/dnszones/tests/rg_name.tftest.hcl` asserting `output.resource_group_name == "rg-hub-prd-dns-swc-001"` (spec US1 scenario 3, FR-009)
- [X] T024 [P] [US1] Write `terraform/dns/tests/plan_zero_diff.tftest.hcl` running plan twice and asserting the second is a zero-diff (FR-026, SC-002, spec US1 scenario 4)

### Implementation for User Story 1

- [X] T025 [US1] Extend `modules/dnszones/main.tf` with `module "zone" { for_each = local.effective_zones; source = "Azure/avm-res-network-privatednszone/azurerm"; version = "~> 0.5"; domain_name = each.value.fqdn; resource_group_name = module.rg.name; tags = each.value.tags }` (research.md D7, FR-025)
- [X] T026 [US1] Wire `modules/dnszones/outputs.tf` `zone_ids` to `{ for k, m in module.zone : k => m.resource_id }`, `zone_names` to `{ for k, v in local.effective_zones : k => v.fqdn }`, `resource_group_name`/`resource_group_id`/`naming` to their sources (FR-020–FR-024)
- [X] T027 [US1] Run `terraform test` in `modules/dnszones/` and `terraform/dns/` and confirm T020–T024 pass

**Checkpoint**: US1 is fully functional — catalogue-only deploy works, consumer contract holds.

---

## Phase 4: User Story 2 — Operator extends catalogue with a bespoke zone (Priority: P1)

**Goal**: Adding an FQDN to `custom_zones` creates exactly one new zone; the FR-016 regex, FR-017 shadowing, and FR-019 duplicate hard-fails all fire at plan time.

**Independent Test**: Set `custom_zones = ["internal.example.com"]` → plan shows 1 add, 0 change, 0 destroy; invalid FQDN → plan-time fail; shadowed FQDN → plan-time fail (spec US2 scenarios 1–4).

### Tests for User Story 2

- [X] T028 [P] [US2] Write `modules/dnszones/tests/custom_zone_added.tftest.hcl` setting `custom_zones = ["internal.example.com"]` and asserting `output.zone_ids["internal.example.com"]` is non-null and `output.zone_names["internal.example.com"] == "internal.example.com"` (spec US2 scenario 1, FR-024)
- [X] T029 [P] [US2] Write `modules/dnszones/tests/custom_zones_reorder.tftest.hcl` with two `run` blocks using the same two custom FQDNs in opposite orders, asserting `run.order_a.zone_ids == run.order_b.zone_ids` (spec US2 scenario 2, FR-027, SC-002)
- [X] T030 [P] [US2] Write `modules/dnszones/tests/custom_zones_shadow.tftest.hcl` with `expect_failures = [check.assertions]` (or the equivalent precondition reference) for `custom_zones = ["privatelink.blob.core.windows.net"]` (spec US2 scenario 3, FR-017, DNS-INV-3, SC-005)
- [X] T031 [P] [US2] Write `modules/dnszones/tests/custom_zones_invalid_fqdn.tftest.hcl` with `expect_failures = [var.custom_zones]` for `custom_zones = ["not_a_valid_dns_name"]` (spec US2 scenario 4, FR-016, DNS-INV-7, SC-005)
- [X] T032 [P] [US2] Write `modules/dnszones/tests/custom_zones_duplicate.tftest.hcl` with `expect_failures = [var.custom_zones]` for `custom_zones = ["a.example.com", "a.example.com"]` (FR-019, DNS-INV-4, SC-005)

### Implementation for User Story 2

- [X] T033 [US2] Confirm `local.custom_map` and `local.effective_zones` in `modules/dnszones/locals.tf` already merge custom zones with catalogue zones (from T008) — adjust as needed so custom FQDNs key by FQDN (FR-024)
- [X] T034 [US2] Tighten the per-element FQDN regex in `var.custom_zones` `validation` in `modules/dnszones/variables.tf` to the exact FR-016 form (`label = [a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?`, ≥2 labels, total ≤253) — message MUST name each offending entry (SC-005)
- [X] T035 [US2] Tighten the DNS-INV-3 shadowing precondition message in `modules/dnszones/check.tf` to enumerate the shadowed FQDN(s) by name (FR-017 message contract)
- [X] T036 [US2] Run `terraform test` and confirm T028–T032 pass

**Checkpoint**: US2 works — bespoke zones extend the catalogue cleanly with full hard-fail coverage.

---

## Phase 5: User Story 3 — Operator disables a catalogue zone (Priority: P2)

**Goal**: Adding a catalogue key to `disable_catalogue_zones` removes exactly that one zone from the effective set; unknown keys hard-fail at plan time.

**Independent Test**: `disable_catalogue_zones = ["acr"]` → `output.zone_ids` does NOT contain `"acr"`; unknown key → plan-time fail (spec US3 scenarios 1–3).

### Tests for User Story 3

- [X] T037 [P] [US3] Write `modules/dnszones/tests/disable_acr.tftest.hcl` setting `disable_catalogue_zones = ["acr"]` and asserting `!contains(keys(output.zone_ids), "acr")` and `length(output.zone_ids) == 24` (spec US3 scenario 1)
- [X] T038 [P] [US3] Write `modules/dnszones/tests/disable_unknown_key.tftest.hcl` with `expect_failures = [check.assertions]` for `disable_catalogue_zones = ["frobnicate"]` (spec US3 scenario 3, FR-018, DNS-INV-5, SC-005)
- [X] T039 [P] [US3] Write `modules/dnszones/tests/disable_all.tftest.hcl` setting `disable_catalogue_zones = keys(local.catalogue)` and asserting `length(output.zone_ids) == 0` and `output.resource_group_name` is still set (edge case "Catalogue is entirely disabled")
- [X] T040 [P] [US3] Write `modules/dnszones/tests/disable_duplicate.tftest.hcl` with `expect_failures = [var.disable_catalogue_zones]` for `disable_catalogue_zones = ["acr", "acr"]` (FR-019, DNS-INV-6, SC-005)

### Implementation for User Story 3

- [X] T041 [US3] Confirm `local.enabled_catalogue` filter in `modules/dnszones/locals.tf` correctly omits disabled keys from `local.effective_zones` (from T008) — adjust if needed
- [X] T042 [US3] Tighten the DNS-INV-5 precondition message in `modules/dnszones/check.tf` to name each unknown key and list valid catalogue keys (FR-018 message contract)
- [X] T043 [US3] Run `terraform test` and confirm T037–T040 pass

**Checkpoint**: US3 works — disable escape-hatch is safe and well-validated.

---

## Phase 6: User Story 4 — Migrate legacy DNS stack — *N/A in v1*

Reserved for a future migration feature. No tasks in this release.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Snapshot fixture, root-stack tests, CI wiring, docs, and final SC verification.

- [X] T044 [P] Add SC-004 plan-delta test `modules/dnszones/tests/disable_one_plan_delta.tftest.hcl`: with `disable_catalogue_zones = ["acr"]` applied to a state seeded by `run "baseline"` (no disables), assert the next plan shows exactly 1 destroy and 0 add / 0 change
- [X] T045 [P] Add SC-003 plan-delta test `modules/dnszones/tests/add_one_plan_delta.tftest.hcl`: with `custom_zones = ["internal.example.com"]` applied to a state seeded by `run "baseline"` (empty), assert the next plan shows exactly 1 add and 0 change / 0 destroy
- [X] T046 [P] Capture reference snapshot manually: run `terraform plan -out=ref.plan -var-file=...` then `terraform show -json ref.plan | jq '.planned_values.outputs.zone_ids.value'` and commit the JSON output to `modules/dnszones/tests/fixtures/zone_ids_snapshot.json` (and the same for `zone_names_snapshot.json`). Document the exact command in `modules/dnszones/tests/fixtures/README.md` (research.md D10, FR-028, SC-007)
- [X] T047 [P] Write `modules/dnszones/tests/determinism_snapshot.tftest.hcl` asserting `jsonencode(output.zone_ids) == file("tests/fixtures/zone_ids_snapshot.json")` and the same for `zone_names` (SC-007)
- [X] T048 [P] Write `terraform/dns/tests/plan_snapshot.tftest.hcl` running plan with reference inputs and asserting `output.zone_ids` matches the committed snapshot byte-for-byte (SC-007)
- [X] T049 [P] Write `terraform/dns/tests/subscription_mismatch.tftest.hcl` with `expect_failures = [check.subscription_match]` for `subscription_id = "11111111-1111-1111-1111-111111111111"` (FR-029, DNS-INV-8, SC-005)
- [X] T050 [P] Write `terraform/dns/tests/wrong_topology.tftest.hcl`, `wrong_environment.tftest.hcl`, `wrong_region.tftest.hcl` with `expect_failures = [var.topology]` / `[var.environment]` / `[var.region]` (FR-001, DNS-INV-9, SC-005)
- [X] T051 [P] Create `modules/dnszones/README.md` documenting inputs, outputs, catalogue, hard-fails, and the AVM dependency (Constitution VI)
- [X] T052 [P] Create `terraform/dns/README.md` with the quickstart.md operator commands inlined (init/plan/apply, backend-config snippet, RBAC requirements)
- [X] T053 [P] Create `.github/workflows/dns.yml` CI workflow running `terraform fmt -check`, `terraform validate`, and `terraform test` in both `modules/dnszones/` and `terraform/dns/` on every PR touching `modules/dnszones/**`, `terraform/dns/**`, or `variables/hub/prd/dns.tfvars.json` (FR-030)
- [X] T054 Grep audit for SC-008: `grep -rE "(privatelink|rg-hub-prd-dns)" modules/dnszones/*.tf terraform/dns/*.tf` MUST return zero matches outside `modules/dnszones/catalogue.tf` (no hand-built names)
- [X] T055 Run quickstart.md §4 determinism check end-to-end and confirm zero diff between the two plans (SC-002, SC-007) — **covered-equivalent in v1** by T024 (`plan_zero_diff.tftest.hcl`) and T029 (`custom_zones_reorder.tftest.hcl`) under `mock_provider`; full live-Azure run deferred until a prd-hub subscription + state backend are available
- [X] T056 Final pass: run `terraform fmt -recursive modules/dnszones/ terraform/dns/`, then `terraform test` in both directories, then verify against [contracts/dns-stack.md](contracts/dns-stack.md) Compatibility table that the output surface matches exactly

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately.
- **Foundational (Phase 2)**: depends on Phase 1; BLOCKS all user stories.
- **User Story 1 (Phase 3)**: depends only on Phase 2.
- **User Story 2 (Phase 4)**: depends only on Phase 2 (uses the same wrapper; orthogonal to US1).
- **User Story 3 (Phase 5)**: depends only on Phase 2.
- **Polish (Phase 7)**: depends on all user stories so the snapshot reflects the final shape.

### Within Each User Story

- Tests are written FIRST (T020–T024, T028–T032, T037–T040, T044) and MUST FAIL before implementation begins for that story.
- Locals/catalogue before module instantiation (already enforced by Phase 2 ordering).
- Implementation before re-running tests for the green check.

### Parallel Opportunities

- **Phase 1**: T002, T003, T004, T005 are independent files → all `[P]`.
- **Phase 2**: T006–T018 mostly write distinct files; sequence is enforced only where one file imports symbols from another (e.g. T009 depends on T006/T007/T008; T010 depends on T009; T011 depends on T008). T019 is the final gate.
- **Phase 3 tests**: T020–T024 each touch a distinct file → all `[P]`.
- **Phase 4 tests**: T028–T032 each touch a distinct file → all `[P]`.
- **Phase 5 tests**: T037–T040 each touch a distinct file → all `[P]`.
- **Phase 7**: T044–T053 are independent files → all `[P]`. T054–T056 run sequentially as final gates.
- **Cross-phase**: Once Phase 2 completes, US1, US2, and US3 can be developed in parallel by different operators.

---

## Parallel Example: User Story 1 tests

```text
# All five test files are independent — start them simultaneously:
T020  modules/dnszones/tests/catalogue_completeness.tftest.hcl
T021  modules/dnszones/tests/zone_keys_default.tftest.hcl
T022  modules/dnszones/tests/zone_name_blob.tftest.hcl
T023  modules/dnszones/tests/rg_name.tftest.hcl
T024  terraform/dns/tests/plan_zero_diff.tftest.hcl
```

---

## Implementation Strategy

**MVP scope = User Story 1** (Phases 1 + 2 + 3 + the snapshot tasks T046–T048 from Phase 7). At that point a consumer can already read `zone_ids` for any of the 25 catalogue keys, the stack is deterministic, and the four cross-cutting hard-fails (FR-001, FR-017, FR-018, FR-029) work — even though `custom_zones` (US2) and `disable_catalogue_zones` (US3) have not yet had their dedicated test coverage.

**Incremental delivery**:

1. MVP: ship US1 → consumers in the prd hub can resolve catalogue zones.
2. +US2: bespoke-zone extension lands in the next PR.
3. +US3: disable escape-hatch lands.
4. Polish (Phase 7) is folded into each PR — the snapshot fixture lands with US1, CI workflow lands as part of MVP, READMEs land with the relevant feature PR.

---

## Format Validation

Every task above conforms to `- [ ] TXXX [P?] [USx?] Description with file path` — verified by inspection.
