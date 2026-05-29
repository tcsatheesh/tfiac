# Phase 0 Research: Naming Convention Engine

## Decisions

### D1. Implementation language

- **Decision**: Pure HCL (Terraform 1.9+). No external code generator,
  no `external` data source, no `null_resource` shelling out.
- **Rationale**: The engine is a string/map transform over a small
  catalogue. HCL's `for`/`merge`/`sort`/`format` primitives, combined
  with `variable` validation and `precondition`/`postcondition`, cover
  every requirement. Adding a code generator would introduce a build
  step inconsistent with the constitution's provider-and-state hygiene
  posture and break SC-003 (deterministic byte-identical output).
- **Alternatives considered**:
  - **Python/Go generator emitting `.tf` files**: rejected. Adds a
    build step and a second source of truth.
  - **Terragrunt**: rejected. Adds a non-AzureRM dependency to every
    consumer and is not required by the constitution.

### D2. Test framework

- **Decision**: `terraform test` (HCL native, available since 1.6).
- **Rationale**: Zero external dependencies; runs in CI with the same
  Terraform binary used for `plan`/`apply`; supports `assert` blocks
  for output validation and `expect_failures` for fail-loudly checks.
- **Alternatives considered**:
  - **Terratest (Go)**: rejected. Adds Go toolchain and a separate
    test dependency tree for what is a pure-HCL transform.
  - **Kitchen-Terraform / InSpec**: rejected as over-engineered for a
    map-transform module.

### D3. Catalogue storage

- **Decision**: Catalogues live in two HCL files under
  `modules/naming/catalogue/` — `services.tf` (a `locals { services
  = { ... } }` block) and `regions.tf`. They are imported into the
  engine via plain `local.services` / `local.regions` references.
- **Rationale**: Keeping catalogues as HCL `locals` makes them
  available at `terraform plan` time without a `data` or `file()`
  call, preserves SC-003 (no file-mtime sensitivity), and makes
  catalogue diffs reviewable in PRs as ordinary HCL changes.
- **Alternatives considered**:
  - **JSON/YAML side-files loaded with `jsondecode(file(...))`**:
    rejected. Adds file I/O to the engine, complicates `terraform
    test`, and offers no real benefit for ~30 rows.
  - **Separate Terraform `data` module**: rejected as unnecessary
    indirection at this scale.

### D4. Instance-numbering algorithm

- **Decision**: At plan time, the engine builds a sorted list of
  top-level entries keyed by `(service_type, service_purpose, key)`,
  then walks the list and assigns `format("%03d", index_within_group +
  1)` as the `instance`. Child positional numbering follows the same
  pattern keyed by `(child_type, parent_canonical_name, key)`.
- **Rationale**: Pure HCL; deterministic; reproducible without any
  state. Sorting on the caller-supplied `key` means file order is
  irrelevant (SC-003).
- **Alternatives considered**:
  - **Hash-based instance derivation** (`format("%03d",
    parseint(substr(sha256(key), 0, 4), 16) % 1000)`): rejected.
    Collisions are possible and the resulting names are unreadable.
  - **Caller-supplied `instance`**: rejected during clarify (chose
    engine-assigned in Q2 of session 2).

### D5. Validation strategy

- **Decision**: Three layers, all native to Terraform:
  1. `variable` validation blocks on every input (regex per spec).
  2. `precondition` blocks in `locals.tf` for cross-field invariants
     (e.g. duplicate `key` within a group; unknown `service_type`;
     overflow against `azure_max`).
  3. `postcondition` on `output "names"` confirming each canonical
     name matches its `service_type`'s declared format and length.
- **Rationale**: Errors surface at `terraform validate` or
  `terraform plan`, never at `apply`. Each layer maps to spec
  invariants 1:1, so test coverage is mechanical.
- **Alternatives considered**:
  - **CI-only linting**: rejected. Errors must fire in the developer's
    local `terraform plan`, not only in CI.

### D6. Catalogue evolution / spec-as-gate

- **Decision**: Adding a new `service_type` requires (a) a new row in
  the spec table and (b) the same row in `catalogue/services.tf`. CI
  enforces this via a small `terraform test` fixture that asserts
  every `service_type` in the catalogue appears in the spec table
  (parsed by a tiny script in CI), and vice-versa.
- **Rationale**: Keeps spec.md authoritative without a separate
  governance process.
- **Alternatives considered**:
  - **Spec-only, no test**: rejected — drift is inevitable.
  - **Catalogue-only, regenerate spec**: rejected — spec is the
    human-reviewed contract.

## Open follow-ups (deferred to /speckit.tasks)

- Initial catalogue population: the spec's 27 top-level rows + 8
  child rows need transcribing into `catalogue/services.tf` in the
  same order to make diffs readable.
- The CI consistency check (D6) needs a small shell or Python script
  to parse the spec table; defer concrete language choice to
  `/speckit.tasks`.
- Example consumer (`terraform/_examples/naming/`) needs a realistic
  service set; defer the exact list to `/speckit.tasks`.
