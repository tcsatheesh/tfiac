# Naming Convention & CAF Conformance Checklist: Naming Convention Engine

**Purpose**: Validate that the requirements covering name generation
and Microsoft Cloud Adoption Framework (CAF) conformance are complete,
clear, consistent, and measurable for every resource type the engine
must emit. This is a "unit test for the spec", not for the
implementation.
**Created**: 2026-05-28
**Feature**: [spec.md](../spec.md)
**Depth**: Formal pre-merge release gate

## Catalogue Completeness

- [x] CHK001 Does the spec enumerate every `service_type` the engine must support, or is the catalogue defined only by example? [Completeness, Spec §FR-009, §FR-026]
- [x] CHK002 Is the inventory of "every service type already used by modules in this repository" stated explicitly (vs. referenced by phrase only)? [Gap, Spec §FR-009]
- [x] CHK003 Are CAF abbreviations specified for every catalogued `service_type`, including child-only types (`subnet`, `nsg_rule`, `route`, `private_endpoint`, `diagnostic_setting`)? [Completeness, Spec §FR-009, §FR-026]
- [x] CHK004 Is the source/version of CAF abbreviations identified (which CAF revision, which Microsoft Learn page, what date)? [Traceability, Gap]
- [x] CHK005 Are the full list of Azure regions the engine must accept (and their short codes) defined, or only the examples `uksouth → uks`? [Completeness, Spec §FR-010]
- [x] CHK006 Is the source/authority for region short-codes documented (e.g. CAF abbreviation list vs. internal mapping)? [Traceability, Spec §FR-010]
- [x] CHK007 Are the `topology_scope` values for every catalogued top-level service type specified in the spec, or only for the day-one seeded subset? [Completeness, Spec §FR-033, §FR-034]

## Per-Service Constraint Clarity

- [x] CHK008 Are per-service maximum length, allowed character set, hyphen-allowed flag, case rule, and must-start-with-letter rule defined as concrete values per `service_type`, or only as a generic schema? [Clarity, Spec §FR-011]
- [x] CHK009 Is the hyphen-allowed vs. hyphen-forbidden classification listed concretely per service type (e.g. is `storage` flagged hyphen-forbidden, is `keyvault` flagged hyphen-allowed)? [Completeness, Spec §FR-003, §FR-005]
- [x] CHK010 Is the documented "regex per shape" referenced by FR-016 actually written out somewhere the consumer can read? [Gap, Spec §FR-016, §FR-023]
- [x] CHK011 Are the per-service charset rules consistent with Azure's published constraints for each service (no requirement that contradicts Azure's own limits)? [Consistency, Spec §FR-011, §FR-016]
- [x] CHK012 Is the engine's CAF conformance claim ("conforms to Microsoft Cloud Adoption Framework guidance") tied to specific CAF rules, or is it a general assertion? [Measurability, Spec §FR-002]

## Canonical Shape Coverage

- [x] CHK013 Is the canonical shape for top-level hyphen-allowed services unambiguously specified including segment order, separator, case, and instance padding? [Clarity, Spec §FR-004]
- [x] CHK014 Is the canonical shape for top-level hyphen-forbidden services unambiguously specified including segment order, allowed charset, and case? [Clarity, Spec §FR-005]
- [x] CHK015 Is the canonical shape for purpose-keyed children of hyphen-forbidden parents specified (FR-030 explicitly omits the purpose-keyed × hyphen-forbidden combination — is this intentional or a gap)? [Gap, Spec §FR-030]
- [x] CHK016 Is the canonical shape for the per-stack resource group fully specified (instance segment, hyphen treatment, CAF abbreviation token)? [Clarity, Spec §FR-025]
- [x] CHK017 Is the recoverability rule ("parent must be recoverable from the child name") testable for every documented child shape? [Measurability, Spec §FR-030]

## Numbering & Determinism

- [x] CHK018 Are the three numbering rules (top-level per batch, positional-child per parent, purpose-keyed has no number) consistent with each other and with the canonical shapes? [Consistency, Spec §FR-008, §FR-030]
- [x] CHK019 Is the instance segment width (3-digit zero-padded) consistent across top-level and positional-child shapes? [Consistency, Spec §FR-004, §FR-030]
- [x] CHK020 Does the spec define the maximum instance number the engine must support (does `999` overflow fail, or is it permitted)? [Gap, Edge Case, Spec §FR-008, §FR-023]
- [x] CHK021 Are determinism requirements measurable (e.g. "byte-identical" is precise; are inputs `region` and `services[]` declared order-sensitive vs. order-insensitive in a testable way)? [Measurability, Spec §FR-006]

## Tagging Requirements Quality

- [x] CHK022 Is the source of every baseline tag value specified (e.g. `repo` — derived from git remote? caller-supplied? hard-coded?) without leaving "the repository identity" as an ambiguous phrase? [Clarity, Spec §FR-014]
- [x] CHK023 Is the set of baseline tag keys closed (exactly six: `tenant`, `topology`, `environment`, `region`, `managed_by`, `repo`) or open-ended ("at least")? [Clarity, Spec §FR-014]
- [x] CHK024 Are tag-key naming conventions specified (snake_case vs. PascalCase) and consistent with Azure's tag key rules? [Consistency, Gap, Spec §FR-014]

## Topology / Environment Scoping

- [x] CHK025 Are the four `topology_scope` values (`hub-only`, `spoke-only`, `either`, `prd-hub-only`) each unambiguously defined with their pass/fail predicate? [Clarity, Spec §FR-033]
- [x] CHK026 Is the seeded `topology_scope` classification (FR-034) consistent with the inventory of FR-026 (every top-level type listed in FR-026 also appears in FR-034)? [Consistency, Spec §FR-026, §FR-034]
- [x] CHK027 Are `topology_scope` decisions for services not in the day-one seed (e.g. `apim`, `vm`, `public_ip`) specified or deferred? [Gap, Spec §FR-034]
- [x] CHK028 Does the spec define the failure mode when a child's parent has a `topology_scope` the request violates (FR-035 says children "inherit" — is the resulting error message the same as FR-033's)? [Consistency, Spec §FR-033, §FR-035]

## Validation, Errors & Edge Cases

- [x] CHK029 Are the documented hard-error scenarios (unknown service_type, unknown region, invalid tenant, topology/tenant mismatch, scope violation, unresolved parent, duplicate purpose, name overflows length) each tied to a specific error-message contract the user can rely on? [Completeness, Measurability, Spec §FR-016–§FR-022, §FR-029, §FR-032, §FR-033]
- [x] CHK030 Does the spec define behaviour when a per-service length budget is exceeded (FR-016 forbids truncation/hashing — is the recommended remediation documented for every shape)? [Coverage, Edge Case, Spec §FR-016, §FR-022]
- [x] CHK031 Are concurrent or partial-failure semantics specified (FR-033 says "all-or-nothing" — does the same rule apply to FR-016 length failures, FR-017 unknown types, and FR-032 unresolved parents)? [Consistency, Spec §FR-016, §FR-017, §FR-032, §FR-033]
- [x] CHK032 Is the "global uniqueness" assumption for hyphen-forbidden services (storage etc.) backed by a documented uniqueness analysis, or only by FR-022's hand-wave to "allocate a different tenant or region"? [Assumption, Spec §FR-022]
- [x] CHK033 Are zero/empty-state scenarios addressed (e.g. `services: []`, `count: 0`, an empty `subnets:` list, an `overrides: {}` with a key that does not match any generated name)? [Coverage, Edge Case, Spec §FR-013, §FR-015]

## Test-Fixture Requirements

- [x] CHK034 Does FR-023's cross-product fixture requirement explicitly cover every catalogued `service_type` including child-only types, or only top-level types? [Coverage, Spec §FR-023, §FR-026]
- [x] CHK035 Is the snapshot/regression artifact (referenced in research.md) named, located, and lifecycle-described in the requirements (when may it be regenerated, by whom, with what review gate)? [Gap, Spec §FR-006, §FR-023]

## Notes

- Items marked `[Gap]` indicate requirements MISSING from the spec; resolve by adding the requirement, not by adding code.
- Items marked `[Clarity]` / `[Ambiguity]` indicate text in the spec that admits multiple interpretations; resolve by tightening wording, not by code comments.
- Items marked `[Consistency]` flag two parts of the spec that may disagree; resolve by aligning them in the same PR.
- Reviewer/CAF sign-off: this checklist MUST be 100% green before `/speckit.tasks` is run; gaps surfaced here become spec edits, not implementation tasks.
- Check items off as completed: `[x]`.
- 33 of 35 items (94%) carry an explicit `[Spec §FR-*]` traceability anchor; the remaining items (CHK002, CHK004) are pure `[Gap]` callouts and intentionally have no anchor.

### Closure log — 2026-05-28 (Round 2 amendment)

All 35 items resolved by a single spec amendment. Mapping:

| Items | Resolved by |
|-------|-------------|
| CHK001, CHK002, CHK003, CHK009, CHK013, CHK014, CHK027 | FR-026 day-one inventory table (service_type / caf_abbr / shape / topology_scope / category) |
| CHK004, CHK006, CHK012 | FR-036 CAF source pinning |
| CHK005 | FR-010 day-one region catalogue table |
| CHK007, CHK025, CHK026, CHK028 | FR-026 + FR-033 + FR-034 + FR-035 (inventory consistent with topology_scope seed and inheritance rule) |
| CHK008, CHK011 | FR-011 (catalogue contract) + FR-016 (now-explicit regexes + plan-time validation) |
| CHK010 | FR-016 four canonical-shape regexes written verbatim |
| CHK015 | FR-030 explicit prohibition of purpose-keyed × hyphen-forbidden |
| CHK016, CHK017 | FR-025 + FR-030 (RG shape; parent-suffix recoverability via regex + segment equality check) |
| CHK018, CHK019 | FR-008 + FR-030 (numbering rules and 3-digit width are consistent across shapes) |
| CHK020 | FR-008 `001..999` cap with hard-error contract |
| CHK021 | FR-008 explicit `services[]` order-sensitivity clause |
| CHK022 | FR-001 + FR-014 required `repo` input, verbatim into baseline tag |
| CHK023 | FR-014 closed six-key baseline set (`managed_by = "terraform"`) |
| CHK024 | FR-014 snake_case baseline + FR-015 Azure tag-key validation |
| CHK029 | FR-016 + FR-017 + FR-018 + FR-019 + FR-029 + FR-032 + FR-033 + FR-039 error-contract surface |
| CHK030 | FR-016 length-budget error contract (service_type, candidate, byte limit, over-budget bytes, remediation guidance) |
| CHK031 | FR-033 all-or-nothing semantics + FR-016/FR-017/FR-032 raised at plan time |
| CHK032 | FR-037 worst-case uniqueness analysis table with strictly positive headroom |
| CHK033 | FR-039 zero/empty/unmatched-state semantics |
| CHK034 | FR-023 + FR-026 (cross-product fixture covers every catalogued service_type, including child-only via parent context) |
| CHK035 | FR-038 snapshot lifecycle + CI divergence-failure rule |

Status: 35/35 green. Ready for `/speckit.tasks`.
