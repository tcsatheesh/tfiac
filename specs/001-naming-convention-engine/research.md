# Phase 0 Research: Naming Convention Engine

**Status**: All NEEDS CLARIFICATION items from the spec were resolved
during `/speckit.clarify` (Session 2026-05-28). This document captures
technology-decision rationale only.

---

## R-001 — Pure Terraform vs external generator

**Decision**: Implement the engine as a pure-HCL Terraform module with
no external scripting.

**Rationale**:

- Composes natively with existing modules under `modules/` — consumers
  declare `module "naming" { ... }` and pass the output map to other
  modules' `for_each`. No build step, no caching, no drift between
  generator output and Terraform state.
- Plan-time validation comes for free via `variable.validation {}` and
  module `check {}` blocks; failures appear in `terraform plan` output
  exactly where engineers expect them.
- The repository's contributor base already operates Terraform; adding
  a Python or Go generator would expand the toolchain surface for zero
  capability gain on the day-one feature set.

**Alternatives considered**:

- *Python generator emitting `.tf.json`*: rejected — adds a build step,
  separates source of truth from state, requires a parallel CI lane,
  and complicates `terraform fmt` enforcement.
- *External `data "external"` script*: rejected — non-deterministic
  across runners, breaks `terraform plan` portability, and tempts
  shelling out to `az` which is forbidden by the no-secrets
  authentication model.
- *Terragrunt-side logic*: rejected — repo uses bare Terraform; adding
  Terragrunt is a far larger change than this feature is permitted to
  introduce.

---

## R-002 — Terraform version pin

**Decision**: Pin `required_version = "~> 1.9"` in the engine module
and require the same in consuming root stacks.

**Rationale**:

- `check {}` blocks (Terraform 1.5+) and `terraform test` (1.6+) are
  both prerequisites for the validation and idempotency gates this
  spec requires (FR-016, FR-023, SC-003).
- `optional()` with defaults in `object({ ... })` types (1.3+) is
  required by the input contract's child lists.
- `~> 1.9` aligns with what is current as of this feature's date
  (2026-05) and matches the constitution's pinning policy
  (Principle VII).

**Alternatives considered**:

- *`>= 1.6`*: rejected — too loose; minor versions in this band have
  changed `terraform test` semantics; "~> minor" is the constitutional
  default.
- *Latest 1.x with no upper bound*: rejected outright by Constitution
  VII.

---

## R-003 — Provider-less module

**Decision**: Declare `required_providers {}` empty in the engine.

**Rationale**:

- The engine emits names and metadata; it never touches Azure. Forcing
  any provider version on consumers would couple the engine's release
  cadence to `azurerm` upgrades for no reason.
- An empty `required_providers {}` block is the explicit way to tell
  consumers "I will not constrain your provider graph." It also lets
  the harness root (`terraform/_naming_test/`) `init`/`plan` without an
  Azure subscription.

**Alternatives considered**:

- *Omit the block entirely*: rejected — Terraform infers
  `hashicorp/null` etc. in some module-loading paths; explicit empty
  is cleaner and surfaces intent.

---

## R-004 — Catalogue representation: HCL maps vs JSON/YAML files

**Decision**: All catalogues are HCL maps in `catalogue.tf`.

**Rationale**:

- Keeps the engine in one language. `terraform fmt` already enforces
  style across the catalogue.
- Schema is verified by Terraform's type-checker at plan time; a typo
  in a JSON/YAML file would only surface much later.
- `check {}` blocks can assert catalogue completeness across maps
  trivially with `setsubtract(keys(local.caf_abbr),
  keys(local.constraints))`.

**Alternatives considered**:

- *`jsondecode(file("catalogue.json"))`*: rejected — adds an
  unstructured intermediate, weakens type checking, and tempts editors
  to inject schema drift.
- *Per-service `.tf` fragments*: rejected — fragments the source of
  truth and makes completeness checking awkward; SC-004 requires
  "exactly one catalogue file per concern" touched per new service.

---

## R-005 — Determinism gate: snapshot equality

**Decision**: Commit a JSON snapshot of the `names` map for a fixed
reference input under `modules/naming/tests/snapshots/reference.json`
and assert equality in a `.tftest.hcl` test.

**Rationale**:

- Snapshot equality is the most direct possible test of
  "byte-identical names across runs" (Constitution Principle IV,
  spec SC-003).
- Reviewers see snapshot diffs in PRs the same way they would see
  golden-file diffs — diffs are intentional and reviewable, not
  hidden behind clever assertion DSLs.
- The snapshot file is regenerable but never auto-regenerated; a
  change to it requires a deliberate PR commit.

**Alternatives considered**:

- *Hash-of-output assertion*: rejected — hides which name changed.
- *Run-twice in-test comparison*: rejected — proves intra-run
  determinism but not cross-commit stability; doesn't catch the
  case where a refactor changes names unintentionally.

---

## R-006 — Plan-time errors: `validation {}` vs `check {}` vs `precondition {}`

**Decision**: Layered.

| Class of error                               | Mechanism                                        |
|---------------------------------------------|--------------------------------------------------|
| Input shape / single-field regex            | `variable.validation { condition = ..., error_message = ... }` |
| Catalogue cross-consistency                 | Module-level `check {}` block                    |
| Per-name length / charset / topology_scope  | Module-level `check {}` block over the flat output |
| Catalogue completeness (all maps same keys) | Module-level `check {}` block                    |

**Rationale**:

- `validation {}` blocks fail loud at plan time and are the canonical
  way to enforce a regex on a single variable field (e.g. `tenant`
  matches `^(hub|sp(0[1-9]|[1-9][0-9]))$`).
- `check {}` blocks (1.5+) are designed for "cross-cutting invariants"
  — exactly the topology_scope and catalogue-completeness checks.
- `precondition {}` on resources is N/A because the engine declares
  zero resources.

**Alternatives considered**:

- *Use only `check {}` everywhere*: rejected — single-field shape
  errors are clearest as variable validations and surface in the
  exact field the user typed.
- *Use `assert` in `.tftest.hcl` only*: rejected — only fires when
  tests run, not when consumers `terraform plan`. Hard fail must
  happen in the consumer's own plan.

---

## R-007 — `terraform test` adoption

**Decision**: Use `terraform test` (1.6+) with positive and negative
`.tftest.hcl` files under `modules/naming/tests/`.

**Rationale**:

- First-party, no extra tool. CI requires only `terraform` in `PATH`.
- Test files can directly assert on module outputs and can assert that
  a `terraform plan` fails with a specific error message (negative
  fixtures).
- The harness root `terraform/_naming_test/` doubles as a manual
  reproduction surface: `cd terraform/_naming_test && terraform plan`
  exercises the engine without running the test framework.

**Alternatives considered**:

- *Terratest (Go)*: rejected — pulls in Go toolchain for what is
  essentially a pure-function module.
- *kitchen-terraform*: rejected — Ruby dependency, heavier than the
  problem.

---

## R-008 — Harness root naming: `terraform/_naming_test/`

**Decision**: Prefix with underscore.

**Rationale**:

- Existing root stacks under `terraform/` (`buildsvr`, `dns`, `log`,
  `rbac`, `services`, `vnet`) are real landing-zone deployments
  iterated per environment. A harness root that should NEVER be
  applied to Azure needs a visible "this is not a real stack" marker.
- Underscore prefix is the cheapest convention — it sorts to the top
  of directory listings and is trivially excluded by future per-env
  pipelines with a glob.

**Alternatives considered**:

- *Place inside `modules/naming/examples/`*: rejected — `examples/` is
  not picked up by repository-wide `terraform validate` loops; we
  want this stack validated alongside real stacks.

---

## Open items

None. All decisions above are final for this feature; revisiting any of
them is a follow-on spec.
