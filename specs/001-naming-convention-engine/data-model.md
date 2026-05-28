# Data Model: Naming Convention Engine

The engine has no persistent storage. "Entities" are HCL object types
that flow through the seven locals stages. This document fixes the
shape of each stage so future contributors can extend the engine
without reverse-engineering `locals.tf`.

---

## Stage 1 — Intent Record (parsed)

Produced by flattening `var.input.services` and its nested children
into a single list of records.

```hcl
{
  type        = string                       # service_type
  parent_ref  = optional(string)             # null for top-level
  purpose     = optional(string)             # null for positional
  pe_subnet   = optional(string)             # for private_endpoint child only
  raw_index   = number                       # position in the original input (stable ordering key)
}
```

**Invariants**:

- For top-level records: `parent_ref = null`, `purpose = null` (unless
  the type itself happens to be purpose-keyed in future — none today).
- For purpose-keyed children: `purpose != null`, `parent_ref` is the
  parent's `raw_index` until Stage 4 rewrites it as the parent's
  canonical name.
- `raw_index` is the deterministic ordering key for instance numbering
  (FR-008).

---

## Stage 2 — Validated Record

Identical shape to Stage 1. Validation is side-effectual only — if a
record violates a rule, the module fails via `check {}` or
`variable.validation {}`; no record is mutated.

**Validations applied** (spec → mechanism):

| Spec ref | Rule                                          | Mechanism                       |
|----------|-----------------------------------------------|---------------------------------|
| FR-019   | `tenant` matches regex                        | `variable.validation` on `input.tenant` |
| FR-018   | `region` is a known full Azure region name    | `check {}` over `local.region_codes` |
| FR-017   | `type` is in catalogue                        | `check {}` over `local.caf_abbr` |
| FR-020   | topology↔tenant consistency                   | `variable.validation` cross-field |
| FR-026   | child-only types not used at top level        | `check {}` over parsed records |
| FR-027   | child appears under a permitted parent type   | `check {}` over parsed records |
| FR-029   | `purpose` uniqueness per `(parent, child_type)` | `check {}` |
| FR-032   | child's `parent_ref` is resolvable            | `check {}` |
| FR-033   | `topology_scope` satisfied (incl. `prd-hub-only`) | `check {}` over parsed records |

---

## Stage 3 — Numbered Record

```hcl
{
  type        = string
  parent_ref  = optional(string)
  purpose     = optional(string)
  pe_subnet   = optional(string)
  instance    = optional(number)             # null for purpose-keyed children
  raw_index   = number
}
```

**Numbering rules** (FR-008):

- Top-level: `instance = position-of-this-record-among-records-of-this-type-in-this-stack`. Starts at 1.
- Positional child: `instance = position-among-records-of-this-child_type-under-this-parent`. Starts at 1.
- Purpose-keyed child: `instance = null` (omitted from name).

---

## Stage 4 — Shaped Record

```hcl
{
  type           = string
  parent_ref     = optional(string)
  purpose        = optional(string)
  instance       = optional(number)
  shape          = string                    # "hyphenated" | "concatenated"
  caf_abbr       = string                    # looked up from local.caf_abbr
  region_code    = string                    # looked up from local.region_codes
  constraints    = object({ max_len = number, charset = string, hyphen_allowed = bool, must_start_with_letter = bool })
  raw_index      = number
}
```

`shape` is `local.constraints[type].shape`. Lookup is whole-token
(FR-021); prefix matches are impossible because keys are exact.

---

## Stage 5 — Named Record

```hcl
{
  canonical_name = string                    # the output key
  type           = string
  parent         = optional(string)          # canonical name of parent, or null
  instance       = optional(number)          # null for purpose-keyed; omitted from name
  purpose        = optional(string)
  shape          = string
  raw_index      = number
}
```

**Name templates** (FR-004 / FR-005 / FR-030):

| Template | When |
|---|---|
| `{abbr}-{tenant}-{environment}-{region_code}-{NNN}` | top-level, hyphen_allowed=true |
| `{abbr}{tenant}{environment}{region_code}{NNN}` | top-level, hyphen_allowed=false |
| `{abbr}-{purpose}-{parent_tenant}-{parent_env}-{parent_region}-{parent_NNN}` | purpose-keyed child, hyphen_allowed=true |
| `{abbr}-{parent_tenant}-{parent_env}-{parent_region}-{parent_NNN}-{NNN}` | positional child, hyphen_allowed=true |
| (concatenated variants for hyphen_allowed=false) | as above, no separators |

Charset and length asserted in a `check {}` after this stage.

---

## Stage 6 — Tagged Record

```hcl
{
  canonical_name  = string
  service_type    = string
  topology        = string
  tenant          = string
  environment     = string
  region          = string                   # full Azure region name (kept for clarity)
  instance        = optional(number)
  parent          = optional(string)
  resource_group  = string                   # always the per-stack RG canonical name
  tags            = map(string)              # baseline merged with overrides[canonical_name]
  defaults        = map(any)                 # local.defaults[service_type]
  overrides       = map(any)                 # var.input.overrides[canonical_name] or {}
}
```

Baseline tag set (FR-014 / Constitution VIII):

| key          | source                                   |
|--------------|------------------------------------------|
| `tenant`     | `var.input.tenant`                       |
| `topology`   | `var.input.topology`                     |
| `environment`| `var.input.environment`                  |
| `region`     | `var.input.region`                       |
| `managed_by` | literal `"terraform"`                    |
| `repo`       | sourced by the caller; passed via input or read from the harness; final source pinned in `quickstart.md` |

---

## Stage 7 — Emitted

Two outputs:

```hcl
output "names" {
  value = { for r in local.tagged_records : r.canonical_name => r }
}

output "by_type" {
  value = { for t, recs in { for r in local.tagged_records : r.service_type => r... } : t => [for r in recs : r.canonical_name] }
}
```

`output "names"` is the primary contract; `output "by_type"` is a
convenience index for consumers iterating one type at a time.

---

## Cardinality summary

| Stage     | Cardinality vs input |
|-----------|----------------------|
| Stage 1   | sum(services.count) + sum(children) + 1 (RG)  |
| Stage 7   | identical to Stage 1 |

The engine adds exactly one record per batch invocation: the implicit
resource group (`rg-{tenant}-{environment}-{region}-001`).

---

## Catalogue entities (static; defined in `catalogue.tf`)

| Map | Key | Value shape |
|---|---|---|
| `local.caf_abbr`       | `service_type` | string |
| `local.region_codes`   | full Azure region name | string |
| `local.constraints`    | `service_type` | object as in Stage 4 plus `shape` |
| `local.topology_scope` | `service_type` | string in {`hub-only`, `spoke-only`, `either`, `prd-hub-only`} |
| `local.defaults`       | `service_type` | service-specific object |
| `local.child_types`    | parent `service_type` | list of allowed child `service_type` |

Catalogue completeness invariant (asserted by `check {}`):
`keys(local.caf_abbr) == keys(local.constraints) == keys(local.topology_scope) == keys(local.defaults)`
for the set of top-level types. Child-only types appear in
`local.caf_abbr`, `local.constraints`, and `local.defaults` but NOT in
`local.topology_scope` (FR-035).
