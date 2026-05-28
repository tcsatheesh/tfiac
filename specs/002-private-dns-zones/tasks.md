# Tasks: Private DNS Zones (prd-hub-only)

**Input**: Design documents from [specs/002-private-dns-zones/](.)

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: REQUIRED — the spec mandates `terraform test` fixtures (FR-030), determinism snapshot (FR-028), and plan-time hard-fail tests (FR-031). All test tasks below are non-optional.

**Organization**: Tasks are grouped by user story. US1, US2, US4 are P1; US3 is P2. The MVP is US1 alone (consumers can read `zone_ids` for the day-one catalogue). US2 + US4 are required to ship to production.

**Design rule (encapsulation)**: The `modules/dnszones/` module OWNS the catalogue, and the module OWNS every validation that depends on catalogue contents. Exposing `local.catalogue` as a public output to enable parent-side validation would leak internals and force every future consumer of the module to reimplement the same check. Catalogue-dependent guards therefore live in the module's `variables.tf` (variable `validation` blocks) or, as a documented fallback, in a `precondition` on a module resource.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependencies on incomplete tasks)
- **[Story]**: US1, US2, US3, or US4 (omitted for Setup / Foundational / Polish)
- All paths are absolute or workspace-relative from repository root.

## Path Conventions

Terraform monorepo. Three artefacts touched:
- `modules/naming/` (extension)
- `modules/dnszones/` (new)
- `terraform/dns/` (replaced)
- `variables/prd/hub/` (one reference tfvars)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the skeletons of the new module and the replacement root stack. No logic yet.

- [X] T001 Create directory [modules/dnszones/](modules/dnszones/) with empty placeholder files `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `README.md`
- [X] T002 Create directory [terraform/dns/tests/](terraform/dns/tests/) and [terraform/dns/tests/snapshots/](terraform/dns/tests/snapshots/) (will hold `.tftest.hcl` fixtures + reference.json)
- [X] T003 [P] Capture the legacy state by running `terraform state list` (or equivalent) against the existing [terraform/dns/](terraform/dns/) backend and saving the inventory to `specs/002-private-dns-zones/legacy-state-inventory.txt` for the US4 `moved {}` block authoring. Do NOT delete the legacy files yet.
- [X] T004 [P] In [terraform/dns/providers.tf](terraform/dns/providers.tf) (new file alongside the legacy one — keep both during the diff), draft the `terraform { required_version = "~> 1.9" required_providers { azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" } } }` block + `provider "azurerm" { features {} subscription_id = var.subscription_id }`. File will replace the legacy `providers.tf` in T039.
- [X] T005 [P] Create [variables/prd/hub/dns.tfvars](variables/prd/hub/dns.tfvars) with the reference input from [quickstart.md](quickstart.md) (`subscription_id`, `region = "uksouth"`, `repo`, `custom_zones = ["internal.contoso.local"]`, `disable_catalogue_zones = []`).

**Checkpoint**: Skeletons exist; legacy stack untouched.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Engine extension + the dnszones module's input/output surface. These BLOCK every user story.

- [X] T006 Extend [modules/naming/catalogue.tf](modules/naming/catalogue.tf) `local.services` with the `private_dns_zone` entry: `{ caf_abbr = "pdnsz", shape = "hyphenated", topology_scope = "prd-hub-only", category = "top-level", max_length = 63, charset = "alphanumeric-hyphen", case_rule = "lowercase", must_start_with_letter = true, child_keys = [] }` per [research.md § 1](research.md).
- [X] T007 Extend [modules/naming/catalogue.tf](modules/naming/catalogue.tf) `local.defaults` with `private_dns_zone = { soa_record_email = null }` per [research.md § 2](research.md). Ensures `check.catalogue_completeness_defaults` continues to pass.
- [X] T008 Run `cd modules/naming && terraform fmt -recursive && terraform validate && terraform test` to confirm the engine extension does not regress the 40 existing fixtures.
- [X] T009 Regenerate [modules/naming/tests/snapshots/reference.json](modules/naming/tests/snapshots/reference.json) using the same `terraform console` pattern as feature 001 (see [quickstart.md § Regenerating](quickstart.md#regenerating-the-determinism-snapshot)). Commit the new bytes.
- [X] T010 [P] Author [modules/dnszones/variables.tf](modules/dnszones/variables.tf) with `naming` (object passthrough of `module.naming.names` — typed as `map(any)`), `region` (string), `region_code` (string — short engine-mapped code such as `uks` for `uksouth`, derived in the root stack from `module.naming` and passed in explicitly to avoid re-deriving it inside the module), `custom_zones` (`list(string)`, default `[]`), `disable_catalogue_zones` (`list(string)`, default `[]`), and `input` (the engine input object for tag derivation per [plan.md Constitution VIII note](plan.md#constitution-check)). Variable-level validations for the FQDN regex and de-dup on `var.custom_zones` and `var.disable_catalogue_zones` per [contracts/input-schema.md](contracts/input-schema.md).

  ADDITIONALLY, catalogue-aware validation for `var.disable_catalogue_zones`:

  - **Primary path (precondition fallback declared as primary for determinism)**: a `precondition {}` block on `azurerm_resource_group.this` in T015 with `condition = length(setsubtract(toset(var.disable_catalogue_zones), toset(keys(local.catalogue)))) == 0` and an error message that prints `setsubtract(toset(var.disable_catalogue_zones), toset(keys(local.catalogue)))` (the offending keys) and `sort(keys(local.catalogue))` (the valid keys). The negative test in T031 targets `expect_failures = [azurerm_resource_group.this]` (`module.dnszones.azurerm_resource_group.this` from the root-stack fixture).
  - **Alternative (only if Terraform parse accepts module-local refs in `variable.validation`)**: an equivalent `validation {}` block on `var.disable_catalogue_zones` referencing `local.catalogue`. If this works, T031 may instead use `expect_failures = [module.dnszones.var.disable_catalogue_zones]`. If it does NOT parse, leave the validation deleted and rely solely on the precondition above. Either way, T010 hands T031 a single concrete target address — no ambiguity at test-write time.

  Record which mechanism (precondition vs variable-validation) was chosen in [modules/dnszones/README.md](modules/dnszones/README.md) (T043).
- [X] T011 [P] Author [modules/dnszones/locals.tf](modules/dnszones/locals.tf) declaring `local.catalogue` — the 25-entry `map(string)` from spec FR-011 (key → FQDN). Verbatim copy of the FR-011 table.
- [X] T012 [P] Author [modules/dnszones/outputs.tf](modules/dnszones/outputs.tf) with `zone_ids`, `zone_names`, `resource_group_name`, `resource_group_id`, AND `catalogue_keys` (the SORTED list of catalogue keys — strings only, not FQDNs — exposed so the root stack can size the engine's `services[].count` per T018). Catalogue VALUES (FQDNs) remain INTERNAL per [contracts/output-schema.md](contracts/output-schema.md).

**Checkpoint**: Engine extended + snapshot regen passing + module surface declared. User stories can start.

---

## Phase 3: User Story 1 — Spoke owner consumes zone_ids (Priority: P1) 🎯 MVP

**Goal**: Spoke stacks can read `zone_ids` for every catalogue zone. Day-one catalogue creates as a single `for_each` resource. Re-plan is zero-diff.

**Independent Test**: From a clean `terraform/dns/`, `terraform plan -var-file=variables/prd/hub/dns.tfvars` shows `+ 1 RG + 25 catalogue zones` and outputs include all 25 catalogue keys in `zone_ids`. Re-plan reports zero changes.

### Tests for User Story 1 (write first, must FAIL before T016/T017 wiring is complete)

- [X] T013 [P] [US1] Create [terraform/dns/tests/positive_baseline.tftest.hcl](terraform/dns/tests/positive_baseline.tftest.hcl): `command = plan`; reference `var.subscription_id`, `var.region = "uksouth"`, `var.repo`, empty `custom_zones`, empty `disable_catalogue_zones`; assert `length(output.zone_ids) == 25`, `output.zone_names["blob"] == "privatelink.blob.core.windows.net"`, `output.resource_group_name == "rg-hub-prd-uks-001"`. Use `mock_provider "azurerm"` with matching `subscription_id`.
- [X] T014 [P] [US1] Create [terraform/dns/tests/determinism_snapshot.tftest.hcl](terraform/dns/tests/determinism_snapshot.tftest.hcl) that asserts `jsonencode({ zone_ids = output.zone_ids, zone_names = output.zone_names }) == file("snapshots/reference.json")` per FR-028 / [research.md § 8](research.md).

### Implementation for User Story 1

- [X] T015 [US1] Author [modules/dnszones/main.tf](modules/dnszones/main.tf) `azurerm_resource_group.this`. Name + tags read from `var.naming["rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"]` (matches the engine's top-level hyphenated shape for `resource_group`; `var.region_code` is supplied by the root stack from `module.naming.region_codes[var.region]`). Location = `var.region`. Add the `precondition {}` block from T010 here (catalogue-aware unknown-disable-key guard).
- [X] T016 [US1] Author [modules/dnszones/main.tf](modules/dnszones/main.tf) `azurerm_private_dns_zone.this` with `for_each = merge({ for k, v in local.catalogue : k => v if !contains(var.disable_catalogue_zones, k) }, { for fqdn in var.custom_zones : fqdn => fqdn })`, `name = each.value`, `resource_group_name = azurerm_resource_group.this.name`, and tags computed per [plan.md Constitution VIII note](plan.md#constitution-check) (engine baseline for catalogue keys; module-internal baseline derived from `var.input` for custom FQDNs — distinguish via `contains(keys(local.catalogue), each.key)`).
- [X] T017 [US1] Author [terraform/dns/variables.tf](terraform/dns/variables.tf) declaring **only** typing and the region allowlist for the five inputs (`subscription_id`, `region`, `repo`, `custom_zones`, `disable_catalogue_zones`). Specifically: type declarations + defaults, plus a `validation {}` block on `var.region` enforcing membership in `local.allowed_prd_hub_regions` (declared in T018). **EXCLUSIVITY**: `var.custom_zones` FQDN-regex validation and de-dup validation are OWNED by T028; `var.disable_catalogue_zones` de-dup validation is OWNED by T033; catalogue-membership validation on `var.disable_catalogue_zones` is OWNED by the module's precondition from T010/T015. Do NOT author any of those in T017.
- [X] T018 [US1] Author [terraform/dns/locals.tf](terraform/dns/locals.tf) declaring:
  - `local.allowed_prd_hub_regions = ["uksouth"]` — region allowlist enforced by T017's `var.region` validation.
  - `local.input` — the engine input object passed to `module.naming`, conforming to the [modules/naming/variables.tf](modules/naming/variables.tf) `input` schema:
    ```hcl
    local.input = {
      topology    = "hub"
      tenant      = "hub"
      environment = "prd"
      region      = var.region
      repo        = var.repo
      services = [
        # One engine service request for the per-stack RG (engine emits it automatically as the parent of every service, but declaring it explicitly keeps the records map auditable):
        # NOTE: the engine catalogue's `resource_group` entry is `managed_by_engine = true`; the RG record is emitted as a side-effect of any service. No explicit entry needed in services[].
        {
          type  = "private_dns_zone"
          count = length(local.catalogue_keys_enabled) + length(var.custom_zones)
        },
      ]
      overrides = {}
    }
    ```
  - `local.catalogue_keys_enabled = sort([for k in module.dnszones.catalogue_keys : k if !contains(var.disable_catalogue_zones, k)])` — the module exposes the sorted catalogue key list (strings only, not FQDNs) via its `catalogue_keys` output (see T012). FQDN values stay internal per [contracts/output-schema.md](contracts/output-schema.md).
  - **Why the engine receives one batched `private_dns_zone` request with `count = N`**: the naming engine's top-level services are instance-suffixed (`pdnsz-hub-prd-uks-001` ... `pdnsz-hub-prd-uks-NNN`), not purpose-keyed (purpose-keyed naming is reserved for child types per [modules/naming/locals.tf](modules/naming/locals.tf) line 149–150). The catalogue key remains the PUBLIC identity per the rewritten FR-007 — it is the `for_each` key in T016, the output key in T020, and the disable key in T010. The engine names INSTANCES by suffix (`pdnsz-hub-prd-<region_code>-NNN`); the Azure resource name is the FQDN from `local.catalogue`. The catalogue key is NOT passed as the engine `purpose`. Document this honestly in [modules/dnszones/README.md](modules/dnszones/README.md) (T043).
- [X] T019 [US1] Author [terraform/dns/main.tf](terraform/dns/main.tf) instantiating `module.naming` (source `../../modules/naming`) with `input = local.input` (the object built in T018, including `services = [{ type = "private_dns_zone", count = N }]` where `N = length(local.catalogue_keys_enabled) + length(var.custom_zones)`). Then instantiate `module.dnszones` (source `../../modules/dnszones`) wiring `naming = module.naming.names`, `region = var.region`, `region_code = module.naming.region_codes[var.region]`, `custom_zones = var.custom_zones`, `disable_catalogue_zones = var.disable_catalogue_zones`, `input = local.input`. **VERIFY** at this task: `module.naming.names` contains at least `rg-hub-prd-<region_code>-001` (the per-stack RG) for T015 to consume. If `module.naming` does not expose `region_codes`, pin the region code via a static map in [terraform/dns/locals.tf](terraform/dns/locals.tf) (`local.region_codes = { uksouth = "uks" }`) and pass that lookup to T019; record the chosen source in [terraform/dns/README.md](terraform/dns/README.md) (T044).
- [X] T020 [US1] Author [terraform/dns/outputs.tf](terraform/dns/outputs.tf) exposing `zone_ids`, `zone_names`, `resource_group_name`, `resource_group_id`, `naming` per [contracts/output-schema.md](contracts/output-schema.md).
- [X] T021 [US1] Generate [terraform/dns/tests/snapshots/reference.json](terraform/dns/tests/snapshots/reference.json) using the `terraform console` procedure in [quickstart.md § Regenerating](quickstart.md#regenerating-the-determinism-snapshot). Commit the bytes.
- [X] T022 [US1] Run `cd terraform/dns && terraform fmt -recursive && terraform validate && terraform test` — T013 + T014 + T022a MUST pass.
- [X] T022a [P] [US1] Create [terraform/dns/tests/positive_replan_zero_diff.tftest.hcl](terraform/dns/tests/positive_replan_zero_diff.tftest.hcl): two `run` blocks with identical baseline inputs (matching T013's tfvars). First block `command = plan` baseline; second block `command = plan` again; assert the second run reports zero resource changes (via `plan.resource_changes` length introspection per Terraform 1.9 `terraform test` framework). Verifies FR-026 / SC-002 (zero-diff re-plan).

**Checkpoint**: US1 MVP — spokes can consume `zone_ids` for the 25 catalogue zones.

---

## Phase 4: User Story 2 — Platform engineer extends catalogue with bespoke zone (Priority: P1)

**Goal**: Operator adds an FQDN to `custom_zones`; exactly one new zone is created; reordering is zero-diff; shadowing and invalid FQDN hard-fail at plan time.

**Independent Test**: With baseline applied, set `custom_zones = ["internal.example.com"]`, `terraform plan` shows exactly one create. Then test shadowing (`["privatelink.blob.core.windows.net"]`) — hard-fail. Then test invalid (`["not_a_valid_dns_name"]`) — hard-fail.

### Tests for User Story 2

- [ ] T023 [P] [US2] Create [terraform/dns/tests/positive_custom_zone_add.tftest.hcl](terraform/dns/tests/positive_custom_zone_add.tftest.hcl): assert with `custom_zones = ["internal.contoso.local"]` that `output.zone_ids["internal.contoso.local"] != null` AND `length(output.zone_ids) == 26`.
- [ ] T024 [P] [US2] Create [terraform/dns/tests/negative_shadowed_fqdn.tftest.hcl](terraform/dns/tests/negative_shadowed_fqdn.tftest.hcl): `command = plan`, `custom_zones = ["privatelink.blob.core.windows.net"]`, `expect_failures = [module.dnszones.azurerm_resource_group.this]` (precondition from T027).
- [ ] T025 [P] [US2] Create [terraform/dns/tests/negative_invalid_fqdn.tftest.hcl](terraform/dns/tests/negative_invalid_fqdn.tftest.hcl): `custom_zones = ["not_a_valid_dns_name"]`, expect `var.custom_zones`'s `validation` block to fail.
- [ ] T026 [P] [US2] Create [terraform/dns/tests/negative_duplicate_entries.tftest.hcl](terraform/dns/tests/negative_duplicate_entries.tftest.hcl): `custom_zones = ["a.b.com", "a.b.com"]`, expect the de-dup `validation` block to fail (FR-019).

### Implementation for User Story 2

- [ ] T027 [US2] Shadowing guard (FR-017) is OWNED by the dnszones module (catalogue lives there, so the comparison lives there). Extend [modules/dnszones/main.tf](modules/dnszones/main.tf) `azurerm_resource_group.this` with a SECOND `precondition {}` block: `condition = length(setintersection(toset(var.custom_zones), toset(values(local.catalogue)))) == 0`; error message names the shadowed FQDN(s) and lists `sort(values(local.catalogue))` as the protected set. No root-stack `check` block is added; the root stack's `var.custom_zones` regex + de-dup validations (T028) stay where they are. The negative test in T024 is updated to target `expect_failures = [module.dnszones.azurerm_resource_group.this]`.
- [ ] T028 [US2] Extend [terraform/dns/variables.tf](terraform/dns/variables.tf) `var.custom_zones` with the FQDN-regex `validation` block AND the de-dup `validation` block per [contracts/input-schema.md](contracts/input-schema.md).
- [ ] T028a [P] [US2] Create [terraform/dns/tests/positive_reorder_no_diff.tftest.hcl](terraform/dns/tests/positive_reorder_no_diff.tftest.hcl): run #1 with `custom_zones = ["a.example.com", "b.example.com"]`; run #2 with `custom_zones = ["b.example.com", "a.example.com"]` (reordered). Assert run #2's plan reports zero resource changes (set-semantics `for_each` keys per FR-025). Verifies FR-027.
- [ ] T029 [US2] Run `cd terraform/dns && terraform fmt -recursive && terraform validate && terraform test` — T023–T026 + T028a MUST pass.

**Checkpoint**: US2 ready — custom zones extend the catalogue cleanly with plan-time guards.

---

## Phase 5: User Story 3 — Platform engineer disables a catalogue zone (Priority: P2)

**Goal**: Operator sets `disable_catalogue_zones = ["acr"]`; that key is omitted from creation and from `zone_ids`; unknown keys hard-fail at plan time.

**Independent Test**: With baseline applied, set `disable_catalogue_zones = ["acr"]`; `terraform plan` shows exactly one destroy (the `acr` zone). Then test unknown key (`["frobnicate"]`) — hard-fail naming the key and listing valid keys.

### Tests for User Story 3

- [ ] T030 [P] [US3] Create [terraform/dns/tests/positive_disable_catalogue_zone.tftest.hcl](terraform/dns/tests/positive_disable_catalogue_zone.tftest.hcl): `disable_catalogue_zones = ["acr"]`, assert `lookup(output.zone_ids, "acr", null) == null` AND `length(output.zone_ids) == 24`.
- [ ] T031 [P] [US3] Create [terraform/dns/tests/negative_unknown_disable_key.tftest.hcl](terraform/dns/tests/negative_unknown_disable_key.tftest.hcl): `disable_catalogue_zones = ["frobnicate"]`; `expect_failures = [module.dnszones.azurerm_resource_group.this]` — targeting the `precondition` block declared by T010 / T015 (the precondition is the primary path per T010's remediation). If T010 chose the optional variable-validation alternative, this address changes to `[module.dnszones.var.disable_catalogue_zones]`; T010 records the chosen target so this test has zero ambiguity. Test intent: an unknown key MUST hard-fail at plan time with a clear message naming the offending key and listing valid catalogue keys.

### Implementation for User Story 3

- [ ] T032 [US3] Confirm the module-side validation authored in T010 catches the unknown-disable-key case end-to-end via T031. No `check "disable_keys_known"` block is added to [terraform/dns/validate.tf](terraform/dns/validate.tf) — the module owns the catalogue and the validation. If any root-stack wiring turns out to be needed (none expected), document it on this task line.
- [ ] T033 [US3] Extend [terraform/dns/variables.tf](terraform/dns/variables.tf) `var.disable_catalogue_zones` with the de-dup `validation` block (FR-019). De-dup is independent of catalogue contents and stays a root-stack concern.
- [ ] T034 [US3] Run `cd terraform/dns && terraform test` — T030 + T031 MUST pass.

**Checkpoint**: US3 ready — operators can carve out catalogue zones hosted elsewhere.

---

## Phase 6: User Story 4 — Migrate legacy DNS stack with zero zone destroys (Priority: P1)

**Goal**: Replace the legacy `modules/dns/` + `terraform/dns/` content with the new engine-driven stack, using `moved {}` blocks for every address change. No `azurerm_private_dns_zone` destroy in the migration plan.

**Independent Test**: Against a saved representative legacy state, `terraform plan` with the new code reports zero `azurerm_private_dns_zone` destroys and the only changes are safe-in-place tag reconciliations (or zero changes entirely).

### Tests for User Story 4

- [ ] T035 [P] [US4] Create [terraform/dns/tests/negative_subscription_mismatch.tftest.hcl](terraform/dns/tests/negative_subscription_mismatch.tftest.hcl): `mock_provider "azurerm"` returning a different `subscription_id` than `var.subscription_id`; `expect_failures = [check.subscription_pinned]` (FR-029, [research.md § 10](research.md)). Although primarily a guard, this test is grouped here because it also protects the migration cut-over against landing in the wrong subscription.
- [ ] T036 [P] [US4] Create [modules/naming/tests/negative_wrong_topology_private_dns_zone.tftest.hcl](modules/naming/tests/negative_wrong_topology_private_dns_zone.tftest.hcl) (the `topology_scope` check is owned by the naming engine, not by the dnszones stack — the right test home is the engine's own test directory). Drive `var.input = { topology = "spoke", tenant = "sp01", environment = "npd", region = "uksouth", repo = "x", services = [{ type = "private_dns_zone", count = 1 }] }`; `expect_failures = [check.topology_scope]` (the literal block name from [modules/naming/validate.tf](modules/naming/validate.tf) line 52).

### Implementation for User Story 4

- [ ] T037 [US4] Add [terraform/dns/validate.tf](terraform/dns/validate.tf) `check "subscription_pinned"` block: condition `var.subscription_id == data.azurerm_client_config.current.subscription_id`; error message names both values (FR-029).
- [ ] T038 [US4] Add `data "azurerm_client_config" "current" {}` to [terraform/dns/main.tf](terraform/dns/main.tf) for T037 to consume.
- [ ] T039 [US4] Author [terraform/dns/moved.tf](terraform/dns/moved.tf) with one `moved {}` block per entry in `specs/002-private-dns-zones/legacy-state-inventory.txt` (T003), mapping each legacy address to its new `module.dnszones.azurerm_private_dns_zone.this["<key>"]` form. Catalogue keys MUST match the FR-011 table; legacy resource names ending in well-known FQDNs map directly to their catalogue key (e.g. legacy `azurerm_private_dns_zone.blob` or `module.dns.azurerm_private_dns_zone.this["privatelink.blob.core.windows.net"]` → `module.dnszones.azurerm_private_dns_zone.this["blob"]`).
- [ ] T040 [US4] DELETE the legacy `modules/dns/` directory entirely (`rm -r modules/dns/`) and DELETE every legacy file in `terraform/dns/` that is not part of the new stack (preserve only the new files authored in Phases 1–6). The replacement `providers.tf` from T004 becomes the canonical providers file.
- [ ] T041 [US4] Run `cd terraform/dns && terraform fmt -recursive && terraform validate && terraform test` — T035 + T036 MUST pass alongside all prior tests.
- [ ] T042 [US4] Generate a `terraform plan` against a representative legacy state (operator runs this against their workstation/CI with backend wired). Capture the plan summary into `specs/002-private-dns-zones/migration-plan-summary.txt`. Confirm zero `azurerm_private_dns_zone` destroys. If any destroy/recreate appears for non-zone resources, surface it under "Operator approval required" in the PR description per FR-033 (manual step, recorded in this file).

**Checkpoint**: US4 ready — migration PR can be opened with confidence.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T043 [P] Update [modules/dnszones/README.md](modules/dnszones/README.md) with: purpose, inputs, outputs, catalogue table (verbatim from FR-011), and the "no providers block" note.
- [ ] T044 [P] Update [terraform/dns/README.md](terraform/dns/README.md) with: stack purpose, consumer snippet from [quickstart.md § Consuming](quickstart.md#consuming-from-a-spoke-stack), failure-modes table from [quickstart.md](quickstart.md), and the snapshot-regen procedure.
- [ ] T045 [P] Run `terraform fmt -recursive .` from repo root; fix any formatting drift introduced by hand-edits.
- [ ] T046 Run `cd modules/naming && terraform test` (includes the relocated T036 fixture) AND `cd modules/dnszones && terraform validate` AND `cd terraform/dns && terraform test` — all green. Capture pass counts for the completion report.
- [ ] T047 Verify SC-008 by grepping the new HCL for hand-built name fragments: `grep -E 'pdnsz-|rg-hub-prd-' terraform/dns/ modules/dnszones/ -rn` MUST return zero matches outside of `tests/` fixtures and `README.md`.
- [ ] T048 Verify SC-001 manually by drafting a sample consumer snippet in `specs/002-private-dns-zones/sample-consumer.tf.example` (NOT applied; reference only) that reads `terraform_remote_state.dns.outputs.zone_ids["blob"]` and creates `azurerm_private_dns_zone_virtual_network_link`. Confirms the contract shape.
- [ ] T049 Validate the spec checklist [specs/002-private-dns-zones/checklists/requirements.md](checklists/requirements.md) is still `[x]` after all task implementation; update only if implementation revealed a gap.

**Final Checkpoint**: All 8 success criteria from spec.md verified; all tests pass; migration plan summary captured.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no deps; start immediately
- **Phase 2 (Foundational)**: depends on Phase 1; BLOCKS all user stories
- **Phase 3 (US1) MVP**: depends on Phase 2
- **Phase 4 (US2)**: depends on Phase 3 (re-uses `terraform/dns/variables.tf`, `validate.tf`, the for_each merge)
- **Phase 5 (US3)**: depends on Phase 2; can run in parallel with Phase 4 (touches different validation block) but `terraform test` runs T029 and T034 sequentially against the same root stack
- **Phase 6 (US4)**: depends on Phase 3 (the new stack must exist before it can be migrated to); can run in parallel with Phase 5
- **Phase 7 (Polish)**: depends on Phases 3–6

### Within Each User Story

- Tests authored BEFORE implementation (US1 tests T013–T014 before T015–T020; US2 tests T023–T026 before T027–T028; US3 tests T030–T031 before T032–T033; US4 tests T035–T036 before T037–T039)
- Tests MUST fail initially → implement → tests pass
- `terraform fmt` + `validate` + `test` is the closing gate of every user story phase

### Parallel Opportunities

- T003, T004, T005 in Phase 1 (different files)
- T010, T011, T012 in Phase 2 (different files within `modules/dnszones/`)
- T013, T014, T022a in Phase 3 (different test fixtures)
- T023, T024, T025, T026, T028a in Phase 4 (different test fixtures)
- T030, T031 in Phase 5
- T035, T036 in Phase 6
- T043, T044, T045 in Phase 7

---

## Parallel Example: User Story 2

```
# Author all four test fixtures simultaneously:
T023 [US2] positive_custom_zone_add.tftest.hcl
T024 [US2] negative_shadowed_fqdn.tftest.hcl
T025 [US2] negative_invalid_fqdn.tftest.hcl
T026 [US2] negative_duplicate_entries.tftest.hcl

# Then implement sequentially:
T027 → T028 → T029
```

---

## Implementation Strategy

### MVP scope (User Story 1 only)

Ship Phases 1–3 + the polish subset (T045–T047) as the smallest deliverable. Consumers can read `zone_ids` for the 25 catalogue zones. No custom zones, no disable, legacy stack still alive in parallel. This proves the engine extension + the thin module + the determinism contract.

### Incremental delivery

1. **Increment 1 — Phase 3 (US1)**: catalogue-only stack, alongside legacy. Consumers may opt in.
2. **Increment 2 — Phase 4 (US2) + Phase 5 (US3)**: catalogue ± custom ± disable. Optional flags only.
3. **Increment 3 — Phase 6 (US4)**: migrate legacy state to the new stack via `moved {}` blocks; delete legacy code. This is the cutover.
4. **Increment 4 — Phase 7 (Polish)**: docs + grep guard + sample consumer.

Each increment ships its own PR. Increment 3 is the only one that touches Azure state in a destructive-eligible way; it has the highest review bar (FR-033).
