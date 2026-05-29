# Implementation Plan: Naming Convention Engine

**Branch**: `001-naming-convention-engine` | **Date**: 2026-05-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [spec.md](spec.md)

## Summary

The Naming Convention Engine is a pure-Terraform module
(`modules/naming/`) that takes a stack-level input bundle plus a list
of service entries and returns a deterministic map keyed by canonical
Azure resource name. Every entry in the output map carries its
`service_type`, the eight baseline tags, plus any `var.extra_tags`.
Consumers (other modules and root stacks) iterate the map via
`for_each`. The engine ships with two built-in catalogues — the
service catalogue (CAF abbreviation, name shape, Azure max length per
`service_type`) and the region lookup (CAF short code → full region
name) — and uses native Terraform `variable` validation, `locals`,
and `precondition` blocks to fail loudly on any violation.

## Technical Context

**Language/Version**: Terraform `~> 1.9` (HCL2). No code outside HCL.

**Primary Dependencies**: None at runtime. AzureRM/AzAPI providers are
**not** required by the engine itself — it produces strings and maps,
nothing else. Consumers pull AzureRM `~> 4.0` per their own
`required_providers`.

**Storage**: N/A — the engine has no state of its own. It is a
stateless transform consumed by other modules.

**Testing**: `terraform test` (native HCL test runner, available since
Terraform 1.6). Tests live under `modules/naming/tests/` and run via
`terraform test` in CI. No external test framework.

**Target Platform**: Linux/macOS developer workstations, GitHub
Actions CI runners. Same Terraform binary everywhere.

**Project Type**: Terraform shared module (single module under
`modules/naming/`) plus example consumer stack and tests. No
application code, no service, no UI.

**Performance Goals**: `terraform plan` time for a 50-entry stack
SHOULD complete the naming-engine portion in < 1 s. The engine is
pure HCL with no `for_each` over external data — overhead is
negligible.

**Constraints**:

- Fail loudly: every input violation, length overflow, missing
  catalogue entry, or duplicate `key` must produce a clear error at
  `terraform validate` or `terraform plan` time, never silently.
- Deterministic: identical inputs → byte-identical output map,
  verifiable via `terraform output -json | diff`.
- No file I/O; engine is a pure transform.
- No external providers required by the engine module.

**Scale/Scope**:

- 26 top-level `service_type` rows + 8 child rows (per spec).
- Up to ~50 service entries per stack in practice; up to 999 instances
  per `(service_type, service_purpose)` group by design.
- Estate-wide: ~6 stacks today (hub × 2 envs, sp01 × 2 envs, dns,
  buildsvr), growing.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md` (v2.2.0).

- [x] **I. Hub-and-Spoke Architecture**: PASS. Engine is topology-
      agnostic; it is consumed identically by hub and spoke stacks.
      No third category introduced.
- [x] **II. Minimal, Intent-Only Inputs**: PASS. Engine inputs match
      the constitution's required surface — tenant, environment,
      region, services list — plus `usecase`, `stack_purpose`,
      `repo` (added by clarify), and a single `var.extra_tags`
      override map. No per-resource tfvars.
- [x] **III. Naming Follows Microsoft CAF**: PASS. The spec's pattern
      table uses CAF abbreviations verbatim; `abbr` column is
      authoritative. Engine refuses any `service_type` not in the
      table (Rules).
- [x] **IV. Determinism and Idempotency**: PASS. Engine sorts entries
      by `(service_type, service_purpose, key)` before numbering;
      file reordering does not affect output. No timestamps, randoms,
      or list-index keys.
- [x] **V. Single Source of Truth for Catalogues**: PASS. The service
      catalogue and region lookup live in `modules/naming/catalogue/`
      and are the only place these facts exist. Consuming modules
      MUST read from the engine output, not redefine.
- [x] **VI. Module Structure is Normative**: PASS. Engine lives at
      `modules/naming/` with standard file layout
      (`main.tf`, `variables.tf`, `outputs.tf`, plus
      `locals.tf`, `catalogue/`, `tests/`). No `providers.tf` —
      engine declares no providers.
- [x] **VII. Provider and State Hygiene**: PASS by exclusion. Engine
      has no providers and no state. Root stacks that consume it
      remain responsible for their own pinning and remote state.
- [x] **VIII. Tagging Baseline**: PASS. Engine emits the eight
      baseline tags per spec; `var.extra_tags` merges additively;
      baseline keys cannot be removed or overridden.
- [x] **IX. Azure Verified Modules First**: N/A. Engine creates no
      Azure resources — it is a string/map transform. AVM applies to
      the consuming modules (`modules/<service>/`), not here.

**Result**: All gates PASS. No complexity-tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/001-naming-convention-engine/
├── plan.md              # This file
├── spec.md              # Authoritative spec (table-driven)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/
    └── naming-engine.md # Phase 1 output (module input/output contract)
```

### Source Code (repository root)

```text
modules/naming/
├── main.tf              # Top-level orchestration: validate → number → name → tag
├── variables.tf         # `input`, `services`, `children`, `extra_tags`
├── outputs.tf           # `names` map (canonical_name → {service_type, tags, ...})
├── locals.tf            # Sorting, instance numbering, name composition
├── catalogue/
│   ├── services.tf      # Local map: service_type → {abbr, shape, azure_max, level}
│   └── regions.tf       # Local map: short_code → full_region_name
└── tests/
    ├── valid.tftest.hcl       # Happy-path: every service_type produces a valid name
    ├── determinism.tftest.hcl # Reorder inputs → identical output
    ├── overflow.tftest.hcl    # Force a kv overflow → expect failure
    ├── duplicate_key.tftest.hcl
    └── catalogue.tftest.hcl   # Unknown service_type / region short code

terraform/_examples/naming/
├── main.tf              # Example: call modules/naming with a realistic set
├── variables.tf
└── outputs.tf           # Re-expose the engine output for diffing
```

**Structure Decision**: A single Terraform module (`modules/naming/`)
with two embedded catalogues and a `tests/` subdirectory running
under `terraform test`. An example consumer at
`terraform/_examples/naming/` doubles as a smoke test and as the
quickstart artefact. No language other than HCL is introduced.

## Phase 0: Outline & Research

See [research.md](research.md).

Unknowns resolved:

- Test framework choice → `terraform test` (HCL native, 1.6+).
- Catalogue storage → in-module `locals.tf` files; no JSON/CSV
  side-files (keeps SC-003 trivial).
- AVM coverage for the engine itself → N/A; engine is not an Azure
  resource.

## Phase 1: Design & Contracts

See [data-model.md](data-model.md), [contracts/naming-engine.md](contracts/naming-engine.md),
and [quickstart.md](quickstart.md).

Post-design constitution re-check: all gates still PASS; no design
choice introduces a new constraint.

## Complexity Tracking

None. All Constitution gates pass.
