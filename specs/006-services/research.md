# Research — Feature 006 — Services

**Status**: regenerated 2026-05-30 against the actual implemented engine at
[modules/naming/](../../modules/naming/) (variables.tf, locals.tf,
outputs.tf, catalogue/services.tf, catalogue/regions.tf). Supersedes any
prior research.md.

All Phase 0 NEEDS CLARIFICATION items resolved below. Citations to the
naming-engine feature use **engine invariants `INV-1..INV-10`** (defined in
`modules/naming/locals.tf` / `check.tf`) and the **spec 001 "Naming Pattern
Table"** / **"Rules"** bullets — never the fictional `engine FR-NNN`
numbers from the original spec ([spec.md CA-007](spec.md#ca-007--engine-citation-fixups-corrects-every-feature-001-fr-nnn-reference-in-specmd-planmd-tasksmd-data-modelmd-researchmd)).

---

## R-1 — How the stack invokes the naming engine

**Decision**. The root stack instantiates `module.naming` with exactly the
engine's documented input contract:

```hcl
module "naming" {
  source = "../../modules/naming"

  input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region          # engine validates against module.catalogue.regions (INV-10)
    usecase       = var.usecase
    stack_purpose = "svc"               # hardcoded per Constitution VI; mirrors terraform/vnet/locals.tf
    repo          = var.repo
  }

  services = local.engine_services      # see R-2
  # children   = []   (default; not used in v1 per spec.md A4)
  # extra_tags = {}   (default; per-entry extra_tags carry overrides)
}
```

**Rationale**. The engine's `var.input` schema is six required fields and
nothing else (see [modules/naming/variables.tf](../../modules/naming/variables.tf)
lines 7–51). Adding any field would fail Terraform's strict object-type
check. `stack_purpose = "svc"` is the stack's identity — same pattern as
`terraform/vnet/locals.tf` (which hardcodes `"net"`).

**Alternatives considered**.
- *Pass `stack_purpose` through `var.stack_purpose`*: rejected — adds a knob
  with exactly one valid value (`"svc"`), violates Constitution II.
- *Let operators pass `services` straight through to the engine without
  expansion*: rejected — operators express intent as `{ type, count, purpose }`
  triplets, the engine wants per-instance entries with deterministic keys.

---

## R-2 — Expanding operator `services` into engine entries

**Decision**. `terraform/services/locals.tf` flattens `var.services` into
`local.engine_services` in three steps (full HCL in
[data-model.md § 3](data-model.md)):

1. **Group** operator entries by `(type, coalesce(purpose, usecase))`.
2. **Sort** within each group by `jsonencode(s)` so re-ordering
   `var.services` produces an identical sorted list per group.
3. **Flatten** each sorted group into engine records, assigning each
   record a synthetic key of the form
   `format("%s%03d%03d", local.type_short[s.type], entry_idx + 1, n)`
   where `entry_idx` is the entry's 0-based position in the sorted group
   and `n` runs `1..s.count` within that entry. The engine then numbers
   the resulting per-`(service_type, service_purpose)` group by SORTED
   key (see `local.services_numbered` in
   [modules/naming/locals.tf](../../modules/naming/locals.tf)), so the
   final instance number is monotonic in `(entry_idx, n)`.

`local.type_short` is a per-type 3-letter slug map (`keyvault → "key"`,
`storage → "sto"`, `log_analytics → "log"`, etc.); the resulting key
length is at most `3 + 3 + 3 = 9` chars, well under the engine's
`^[a-z0-9]{1,16}$` limit.

**Rationale**.
- Engine `INV-4` (in `modules/naming/locals.tf` `services_rg_shape_violations`)
  hard-fails any non-RG, non-FQDN entry whose `service_purpose` is `null`.
  Setting `service_purpose = coalesce(s.purpose, var.usecase)` guarantees
  non-null. Because `var.usecase` is constrained at the stack boundary
  to `^[a-z0-9]{3}$` (a SUBSET of the engine's `^[a-z0-9]{3,4}$`), the
  fallback value always satisfies the engine's stricter `service_purpose`
  regex `^[a-z0-9]{3}$` (see [data-model.md § 1 row 6](data-model.md)).
- Engine `INV-2` (duplicate `(service_type, service_purpose, key)`)
  hard-fails on collisions. Two operator entries that share
  `(type, purpose)` would collide if the synthetic key encoded only the
  instance number `n`. Step 3's `(entry_idx, n)` pair removes the hazard
  while keeping the engine-side sort deterministic. Spec [C-002](spec.md#clarifications)
  explicitly supports two `{ type = "keyvault", count = 1 }` entries
  producing `kv...001` and `kv...002`; this expansion delivers that
  outcome.
- Sorting at step 2 by `jsonencode(s)` means re-ordering `var.services`
  entries that share `(type, purpose, count, overrides)` yields identical
  sorted lists and therefore identical engine keys; engine output is
  byte-equal (FR-015 / [C-002](spec.md#clarifications)).

**Alternatives considered**.
- *Use the canonical name as the engine `key`*: rejected — circular (the
  engine COMPUTES the canonical name FROM the key, instance number, and
  catalogue row).
- *Use `format("i%03d", n)` (no type prefix)*: rejected — two operator
  entries with different `(type, purpose)` could collide on the same
  generated key before grouping, making the intermediate state
  ambiguous. Including the type prefix removes the hazard.
- *Forbid multiple operator entries with the same `(type, purpose)`*:
  rejected — Spec [C-002](spec.md#clarifications) explicitly supports
  the duplicate-entry case; the (entry_idx, n) keying handles it without
  a new validation.

---

## R-3 — Overrides: contract and hard-fail

**Decision**. `var.overrides` is `map(map(any))` keyed by the engine-emitted
canonical name (e.g. `"kvshdshdsp01npduks001"`,
`"log-shd-shd-sp01-npd-uks-001"`). The stack forwards each entry to the
matching wrapper module via the `for_each` lookup
(`overrides = lookup(var.overrides, each.key, {})`). The stack additionally
emits a `check "overrides_keys_resolved"` block that hard-fails at plan time
if any `var.overrides` key is absent from `keys(module.naming.names)`,
listing every unmatched key.

**Rationale**. The naming engine has no `overrides` input ([spec.md CA-006](spec.md#ca-006--stack-owns-unmatched-overrides-hard-fail-corrects-fr-006-fr-018-c-003));
the unmatched-key validation is therefore stack-owned. HCL map keys are
arbitrary strings, so dash-bearing AND concatenated canonical names are
both valid keys ([spec.md C-003](spec.md#clarifications)).

**Alternatives considered**.
- *Key overrides by `(type, instance_index)` tuple*: rejected — operators
  who add or remove a `services[]` entry would silently re-target an
  unrelated instance. Canonical-name keying is stable across reorders.
- *Validate inside each wrapper module*: rejected — defeats the
  defence-in-depth promise and gives confusing per-resource errors instead
  of one consolidated "these N override keys did not resolve" error.

---

## R-4 — Topology and selectable-inventory gating

**Decision**. The stack owns ALL topology-related and inventory-related
hard-fails ([spec.md CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases)):

| Rule | Enforcement |
|---|---|
| `topology=hub ⟺ tenant=hub` and `topology=spoke ⟺ tenant=~/^sp[0-9]{2}$/` | `variable "tenant" { validation { ... } }` referencing `var.topology` |
| `var.services[*].type ∈ local.v1_selectable_types` | `check "v1_selectable_inventory"` emitting one message per offender from `local.deferred_reason` |
| `var.services[*].private_endpoints` empty and `var.services[*].diagnostic_settings` empty in v1 | `variable "services"` validation (A4 guard) |

**Rationale**. The engine has no `topology` input and no `topology_scope`
field on catalogue rows (verified in
[modules/naming/variables.tf](../../modules/naming/variables.tf) and
[modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf)).
Every previous claim of "engine FR-020 / FR-033 hard-fails on topology
mismatch" is fictional ([scratchpad B5](../../temp/scratchpad/006-analyze-findings.md));
moving the rules into the stack's own variable validations and `check`
blocks is the simplest path to the same operator experience without
amending the engine.

**Alternatives considered**.
- *Add `topology_scope` to the engine catalogue and a `topology` input on
  `var.input`*: rejected — out of scope for feature 006 and would force a
  major-version bump of the engine. Defer to a future engine feature if the
  rule needs to be re-used by another stack.

---

## R-5 — Per-service defaults ownership

**Decision**. Per-service SKU / tier / retention / data-plane RBAC defaults
live in each `modules/<service>/locals.tf`. The wrapper merges the stack's
forwarded `overrides` map on top of those defaults inside the AVM call.

**Rationale**. The engine has no `local.defaults` map and no per-type
defaults catalogue ([spec.md CA-005](spec.md#ca-005--per-service-defaults-are-wrapper-owned-corrects-fr-013-a9-c-007-data-model--8));
catalogue rows carry only naming-relevant fields (`abbr`, `shape`,
`azure_max`, `level`, `parent_type`). Placing defaults in the wrapper keeps
the engine pure (naming only) and lets every wrapper opt into its
corresponding AVM module's defaults wholesale where possible.

**Alternatives considered**.
- *Maintain a `terraform/services/defaults.tf` central defaults map*:
  rejected — duplicates Constitution V's "single source of truth" inside the
  stack while putting it in the wrong layer (the stack does not know enough
  about each service's AVM schema to author sensible defaults centrally).

---

## R-6 — `for_each` key strategy for wrapper modules

**Decision**. Every `module "<type>" { for_each = ... }` block in
`terraform/services/main.tf` keys on the engine-emitted canonical name.
The `for_each` expression is:

```hcl
for_each = {
  for name, entry in module.naming.names :
  name => entry
  if entry.service_type == "<type>"
}
```

**Rationale**. Canonical names are deterministic per
[spec.md C-002](spec.md#clarifications); using them as `for_each` keys
delivers FR-011/FR-015's reorder-zero-diff promise without any auxiliary
mechanism. Reordering `var.services` entries whose `(type, purpose, count)`
triplets are unchanged produces the same `(service_type, service_purpose,
sorted_key)` groups and therefore the same instance numbers and the same
canonical names. The set of `for_each` keys is byte-identical across the
reorder.

**Alternatives considered**.
- *Key by `(type, instance_index)` tuple*: rejected — operators who add an
  override of the form `overrides[<canonical_name>]` would need a separate
  tuple-to-name translation table. Canonical-name keying makes the override
  contract direct.
- *List-index keys*: rejected — explicitly forbidden by Constitution IV.

---

## R-7 — Baseline tags

**Decision**. The engine emits the EIGHT-key baseline tag set on every
top-level resource:

```text
tenant, environment, region, managed_by, repo, usecase, stack_purpose, service_purpose
```

(`stack_purpose` is the stack-wide value, except for `resource_group`
entries where it equals the entry's `stack_purpose` override; see
`local.top_level_tags` in [modules/naming/locals.tf](../../modules/naming/locals.tf)).
Per-instance additive tags ride on the engine's per-entry `extra_tags`
slot, MERGED on top by the engine (last writer wins from
`{baseline, var.extra_tags, entry.extra_tags}`). Baseline-key collisions in
either `var.extra_tags` or per-entry `extra_tags` are hard-failed by
engine `INV-8`.

**Rationale**. Verified against `local.baseline_tag_keys` in
`modules/naming/locals.tf` lines 18–27 and the corresponding tag-merge
blocks at lines 282–304. Every prior "six baseline tags" reference in this
spec is incorrect per [spec.md CA-008](spec.md#ca-008--eight-baseline-tags-not-six-corrects-fr-012).

---

## R-8 — Engine output surface

**Decision**. The stack consumes exactly two outputs from `module.naming`:

- `module.naming.engine_version` — semver string, pinned in the stack
  README for change-detection.
- `module.naming.names` — `map(object({ service_type, service_purpose,
  stack_purpose, parent, tags, azure_max }))` keyed by canonical name.

**Rationale**. Verified against
[modules/naming/outputs.tf](../../modules/naming/outputs.tf): the output is
named `names` (the internal local is `local.all_names`, but the exposed
output key is `names`). Previous contract drafts that asserted
`module.naming.all_names` are incorrect ([spec.md CA-010](spec.md#ca-010--naming-output-passthrough-corrects-contractscross-stack-outputsmd-output-naming)).

**Alternatives considered**.
- *Surface `module.naming.names` opaquely as the stack's `naming` output*:
  ACCEPTED for the cross-stack contract (see
  [contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md)).
  The stack's `resource_ids` / `resource_names` outputs are derived FROM
  this map, keyed identically.

---

## R-9 — AVM coverage and wrapper modernisation

**Decision**. Phase 0 audit pins AVM module versions per type. Where AVM
coverage exists, the wrapper delegates to a single
`module "<avm>" { source = "Azure/avm-res-*/azurerm" }` block. Where it
does not, the wrapper hand-rolls once and records a follow-up tracker in
its `README.md`. Day-one AVM-covered types include at least:
`keyvault, storage, log_analytics, container_registry, user_assigned_identity,
app_insights, search` (per Constitution v2.2.0 day-one targets and current
Terraform Registry coverage; exact versions pinned during Phase 0 of
[tasks.md](tasks.md)).

**Rationale**. Constitution Principle IX is mandatory; the only escape is
"no published AVM module". Pinning during Phase 0 prevents AVM upgrades
from leaking into the migration PR.

---

## R-10 — Migration discipline

**Decision**. Replace `terraform/services/` in place; author explicit
`moved {}` blocks for every resource address that changes between the
legacy stack and the engine-driven stack ([spec.md C-004 / FR-023 / FR-024](spec.md#clarifications)).
Back up the pre-cutover files into `temp/scratchpad/006-services-pre-cutover/`
before editing. Any resource that cannot be `moved {}`-translated without
recreation MUST be called out in the PR description under an "Operator
approval required" heading.

**Rationale**. CLAUDE.md standing rule: "Defaults preserve existing
behaviour"; soft-delete-bearing resources (`keyvault`, `storage`) are
unrecoverable inside their soft-delete window if recreated. `moved {}` is
the only zero-downtime translation HCL offers.

---

## R-11 — CI / runtime `subscription_id` injection

**Decision**. The repo's `.github/workflows/deploy.yaml` injects
`subscription_id` via the `-var` CLI flag
(`-var "subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}"`). Local
shells use `TF_VAR_subscription_id` per long-standing Terraform convention.
The committed tfvars carry the literal placeholder
`REPLACE-WITH-RUNTIME-SUBSCRIPTION-ID`, which the stack's
`variable "subscription_id"` validation regex rejects loudly.

**Rationale**. Both paths are Terraform-native. Verified against
`.github/workflows/deploy.yaml` ([spec.md CA-011](spec.md#ca-011--subscription_id-runtime-injection-cli-or-env-corrects-c-005-quickstart-troubleshooting)).
The placeholder + regex combination converts "operator forgot to inject"
from an Azure-time crypto error into a Terraform-time validation error.

---

## R-12 — Verification of the canonical-name shapes used downstream

**Decision**. Every canonical name asserted in
[data-model.md](data-model.md), [quickstart.md](quickstart.md), and
[contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md) is
re-derived by hand from the engine's `local.top_level_named` expression in
[modules/naming/locals.tf](../../modules/naming/locals.tf), using the
reference invocation
`(stack_purpose="svc", usecase="shd", tenant="sp01", environment="npd",
region="uks", service_purpose="shd")`. Worked examples:

| Operator entry | Engine shape | Reference canonical name |
|---|---|---|
| `{ type = "resource_group" }` (auto-emitted by engine when present in `services`, here implicit per stack convention) | `rg_hyphenated` → `rg-{stack_purpose}-{usecase}-{tenant}-{env}-{region}-{instance}` | `rg-svc-shd-sp01-npd-uks-001` |
| `{ type = "keyvault" }` | `concatenated` → `kv{service_purpose}{usecase}{tenant}{env}{region}{instance}` | `kvshdshdsp01npduks001` (length 21 ≤ azure_max 24) |
| `{ type = "storage", count = 2 }` | `concatenated` | `stshdshdsp01npduks001`, `stshdshdsp01npduks002` |
| `{ type = "container_registry" }` | `concatenated` | `crshdshdsp01npduks001` |
| `{ type = "log_analytics" }` | `hyphenated` → `{abbr}-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `log-shd-shd-sp01-npd-uks-001` |
| `{ type = "app_insights" }` | `hyphenated` | `appi-shd-shd-sp01-npd-uks-001` |
| `{ type = "user_assigned_identity" }` | `hyphenated` (abbr `id`) | `id-shd-shd-sp01-npd-uks-001` |
| `{ type = "search" }` | `hyphenated` (abbr `srch`) | `srch-shd-shd-sp01-npd-uks-001` |
| `{ type = "openai" }` | `hyphenated` (abbr `oai`) | `oai-shd-shd-sp01-npd-uks-001` |
| `{ type = "language" }` | `hyphenated` (abbr `lang`) | `lang-shd-shd-sp01-npd-uks-001` |
| `{ type = "doc_intel" }` | `hyphenated` (abbr `di`) | `di-shd-shd-sp01-npd-uks-001` |
| `{ type = "function_app" }` | `hyphenated` (abbr `func`) | `func-shd-shd-sp01-npd-uks-001` |
| `{ type = "logic_app" }` | `hyphenated` (abbr `logic`) | `logic-shd-shd-sp01-npd-uks-001` |
| `{ type = "aml_workspace" }` | `hyphenated` (abbr `mlw`, azure_max 33) | `mlw-shd-shd-sp01-npd-uks-001` (length 28 ≤ 33) |
| `{ type = "apim" }` | `hyphenated` (abbr `apim`) | `apim-shd-shd-sp01-npd-uks-001` |

For `(topology=hub, tenant=hub, environment=npd, region=uks)` the RG becomes
`rg-svc-shd-hub-npd-uks-001` and every other resource simply substitutes
`hub` for `sp01` in the same positions.

**Rationale**. These are the SAME values the engine produces; data-model,
quickstart, and contracts cite them directly.

---

## Cross-cutting

All R-1..R-12 are consistent with the eight required + one optional stack
inputs defined in [data-model.md § 1](data-model.md), the engine-record
shape in [data-model.md § 3](data-model.md), and the output surface in
[contracts/cross-stack-outputs.md](contracts/cross-stack-outputs.md). No
`NEEDS CLARIFICATION` items remain open.
