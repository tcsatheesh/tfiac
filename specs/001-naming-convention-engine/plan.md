# Implementation Plan: Naming Convention Engine

**Branch**: `001-naming-convention-engine` | **Date**: 2026-05-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [specs/001-naming-convention-engine/spec.md](spec.md)

## Summary

Build a pure-Terraform, provider-less module `modules/naming/` that is the
single source of truth for every Azure resource name produced by this
repository. The engine takes one batch request describing a stack's
topology, tenant, environment, region, and services (with nested children),
expands it through deterministic locals stages
(parsed → validated → numbered → shaped → named → tagged → emitted), and
returns a flat `{canonical_name => record}` map plus a `by_type` index.

Technical approach: all logic lives in HCL locals; catalogues are static
HCL maps; validation is plan-time via `variable.validation {}` and module
`check {}` blocks; testing uses `terraform test` (1.6+) with positive and
negative `.tftest.hcl` fixtures plus a committed snapshot of the reference
output for the idempotency gate (Constitution Principle IV).

## Technical Context

**Language/Version**: Terraform `~> 1.9`. The engine module declares
`terraform { required_version = "~> 1.9" }`; root stacks that consume the
engine pin the same.

**Primary Dependencies**: None at runtime. The engine declares
`required_providers {}` empty so it does not force any provider version on
its consumers.

**Storage**: None. The engine is logic-only — no state of its own beyond
the consumer stack's existing remote state.

**Testing**: `terraform test` (Terraform 1.6+) with `.tftest.hcl` files
under `modules/naming/tests/`. Snapshot equality of the reference `names`
map enforces the determinism gate.

**Target Platform**: Any environment running Terraform 1.9+. The module
is consumed by root stacks under `terraform/<stack>/` and is exercised in
CI by `terraform fmt`, `terraform validate`, and `terraform test`.

**Project Type**: Terraform module library. The repo layout
(`modules/<service>/`, `terraform/<stack>/`, `variables/<env>/<scope>/`)
is preserved per Constitution Principle VI.

**Performance Goals**: Single batch evaluation completes in under 50 ms
for a representative stack on a developer workstation (spec SC-001).
Terraform locals are O(N) over the flattened intent record list; N is
small (tens to low hundreds).

**Constraints**:

- No external scripting, no code generators, no JSON/YAML parsers.
- No `external` data sources, no `null_resource` + `local-exec`.
- No providers required by the engine itself.
- All validation MUST be plan-time and MUST emit messages naming the
  offending input.
- Names MUST be byte-identical across runs (Constitution Principle IV).

**Scale/Scope**: Day-one inventory ≈ 30 top-level service types and 5
child types (spec FR-026 / FR-028). Up to 99 spokes per environment
(FR-019). Up to 999 instances per `service_type` per stack.

## Constitution Check

Source: `.specify/memory/constitution.md` (v2.1.0). Each gate answered
explicitly.

- [x] **I. Hub-and-Spoke Architecture** — PASS. The engine enforces
      topology validity via `topology_scope`, and the new
      `prd-hub-only` value (spec FR-033 / FR-034) machine-checks the
      "one global DNS in prd" rule. The engine itself is stack-
      agnostic; it does not create a hub or spoke, only names them.
- [x] **II. Minimal, Intent-Only Inputs** — PASS. Consumers pass exactly
      `topology`, `tenant`, `environment`, `region`, and `services`.
      All other configuration comes from `local.defaults`. Per-resource
      overrides live in the single `overrides` map keyed by canonical
      name. No per-resource tfvars added.
- [x] **III. Naming Follows Microsoft CAF** — PASS. Names are built
      strictly from the catalogue (CAF abbreviations + region codes +
      per-service constraints). This plan IS the realisation of the
      "naming convention" feature spec the constitution references.
- [x] **IV. Determinism and Idempotency** — PASS. Pure HCL locals; no
      `random_*`, no `timestamp()`, no `uuid()`, no hashes. `for_each`
      keys are canonical names. Snapshot equality test enforces it.
- [x] **V. Single Source of Truth for Catalogues** — PASS. One HCL map
      per concern in `catalogue.tf`; a `check {}` block asserts
      catalogue completeness so no entry can be added in one map and
      forgotten in another. Adding a service type is a single-file PR.
- [x] **VI. Module Structure is Normative** — PASS. New module sits at
      `modules/naming/` with the standard file layout. Tests live under
      `modules/naming/tests/`. A tiny harness root at
      `terraform/_naming_test/` exercises the module via
      `terraform plan`.
- [x] **VII. Provider and State Hygiene** — PASS. Engine declares
      `required_version = "~> 1.9"` and `required_providers {}` empty;
      consumers pin their own providers per root stack. No state of its
      own. No secrets anywhere — engine handles only structural data.
- [x] **VIII. Tagging Baseline** — PASS. Baseline tags `tenant`,
      `topology`, `environment`, `region`, `managed_by = "terraform"`,
      `repo` are emitted on every record; per-name overrides merge on
      top via `merge(baseline, overrides)`, so baseline keys cannot be
      removed.

No FAIL gates. Complexity Tracking table stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-naming-convention-engine/
├── plan.md              # This file
├── spec.md              # Already authored
├── research.md          # Phase 0 output (this command)
├── data-model.md        # Phase 1 output (this command)
├── quickstart.md        # Phase 1 output (this command)
├── contracts/
│   ├── input-schema.md      # variable "input" object schema
│   └── output-schema.md     # names + by_type output schemas
├── checklists/
│   └── requirements.md  # already authored
└── tasks.md             # NOT created here — /speckit.tasks output
```

### Source Code (repository root)

```text
modules/
└── naming/                                  # NEW — the engine
    ├── versions.tf                          # terraform { required_version, required_providers {} } (provider-less)
    ├── main.tf                              # introductory header + entry locals stub
    ├── variables.tf                         # variable "input" with validation {} blocks
    ├── outputs.tf                           # outputs "names" and "by_type"
    ├── locals.tf                            # staged locals
    ├── catalogue.tf                         # central maps
    ├── validate.tf                          # module-level check {} blocks
    ├── README.md                            # contract + worked examples
    └── tests/
        ├── positive_topology.tftest.hcl              # hub + sp01 + sp99; npd + prd + pre; minimal-input sub-run
        ├── positive_regions.tftest.hcl               # uksouth + westus2
        ├── positive_children.tftest.hcl              # vnet+subnets, nsg+rules, storage+PEs
        ├── positive_full_catalogue.tftest.hcl        # one of every top-level service_type
        ├── negative_service_type.tftest.hcl          # unknown service_type
        ├── negative_tenant.tftest.hcl                # sp00, sp1, sp100
        ├── negative_region.tftest.hcl                # unknown region
        ├── negative_topology_scope.tftest.hcl        # dns_zone in (hub,npd); firewall in spoke; function_app in hub
        ├── negative_charset_length.tftest.hcl        # oversized name; illegal charset
        ├── negative_child_invariants.tftest.hcl      # dup purpose; unresolved PE; child at top level; unmatched override; count>999
        ├── catalogue_completeness.tftest.hcl         # services ↔ defaults parity
        ├── catalogue_region_completeness.tftest.hcl  # short-code uniqueness
        ├── catalogue_child_completeness.tftest.hcl   # child parents resolve in services
        ├── tags_baseline.tftest.hcl                  # six-key baseline present on every record
        ├── tags_overrides.tftest.hcl                 # override adds keys, cannot remove baseline
        ├── tags_override_key_validation.tftest.hcl   # reserved prefix; length 513
        ├── determinism_snapshot.tftest.hcl           # names equality vs snapshots/reference.json
        └── snapshots/
            └── reference.json                          # committed snapshot of names for reference input

terraform/
└── _naming_test/                            # NEW — harness root for manual `terraform plan` smoke
    ├── main.tf                              # module "naming" { ... reference input ... }
    ├── outputs.tf                           # forwards names + by_type
    ├── providers.tf                         # required_version "~> 1.9"; no providers
    └── README.md
```

**Structure Decision**: Add exactly two new directories:
[modules/naming/](modules/naming/) (the engine, per Constitution
Principle VI) and [terraform/_naming_test/](terraform/_naming_test/) (a
provider-less harness root for `terraform plan`-based smoke testing).
The underscore prefix marks the harness as not a real landing-zone
stack and excludes it from environment iteration.

## Phase 0 Output

See [research.md](research.md). All NEEDS CLARIFICATION items were
resolved during `/speckit.clarify`; Phase 0 covers technology-decision
rationale only.

## Phase 1 Output

- [data-model.md](data-model.md) — logical data shapes (HCL object
  types).
- [contracts/input-schema.md](contracts/input-schema.md) — the public
  `variable "input"` contract.
- [contracts/output-schema.md](contracts/output-schema.md) — the public
  `names` and `by_type` output contracts.
- [quickstart.md](quickstart.md) — minimal hub + spoke worked example.

## Future Work (out of scope for this feature)

The plan covers ONLY the engine, its catalogue, validation, tests, and
harness root. The following are tracked here but MUST be addressed by
follow-on feature specs (Constitution Principle VI + the spec's FR-024):

- **Per-module consumer migration** — refactor `modules/vnet/`,
  `modules/storage/`, `modules/keyvault/`, `modules/openai/`,
  `modules/apim/`, `modules/aifoundry/`, `modules/aml/`,
  `modules/appinsights/`, `modules/cntreg/`, `modules/docint/`,
  `modules/fnapp/`, `modules/language/`, `modules/lgapp/`,
  `modules/log/`, `modules/search/`, `modules/uai/`, `modules/vm/`,
  `modules/dns/`, `modules/aiservices/`, `modules/rbac/` (RBAC only for
  scope/tag derivation — role-assignment names stay UUIDv5). Each
  migration is its own PR with explicit `moved {}` blocks.
- **Root-stack rewiring** — `terraform/services/`, `terraform/vnet/`,
  `terraform/dns/`, `terraform/log/`, `terraform/rbac/`,
  `terraform/buildsvr/` adopt the engine and drop ad-hoc name
  construction.
- **Multi-region per stack** — the engine accepts a single `region`
  today; a future spec extends the input to a list with deterministic
  numbering across regions.
- **Region-pair / DR semantics** — not modelled.
- **Cost-centre and owner tags** — optional today (Constitution VIII);
  promotion to required is a future amendment.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| — | — | — |

No violations.
