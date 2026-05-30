# Data Model — Feature 006 — Services

**Status**: regenerated 2026-05-30. Every type, regex, and example below is
verified against the implemented engine at
[modules/naming/variables.tf](../../modules/naming/variables.tf),
[modules/naming/locals.tf](../../modules/naming/locals.tf),
[modules/naming/outputs.tf](../../modules/naming/outputs.tf), and
[modules/naming/catalogue/services.tf](../../modules/naming/catalogue/services.tf).
Engine invariants `INV-N` are cited from
`modules/naming/locals.tf` / `check.tf`.

---

## 1. Root-stack input variables (`terraform/services/variables.tf`)

The stack accepts **exactly eight required inputs and one optional input.**
Any other top-level variable is forbidden (Constitution Principle II;
[spec.md CA-002](spec.md#ca-002--usecase-is-the-8th-required-stack-input-corrects-fr-001-a2a5)).

| # | Variable | Type | Required? | Validation (root-stack) | Spec ref |
|---|---|---|---|---|---|
| 1 | `subscription_id` | `string` | **yes** | regex `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` AND `!= "REPLACE-WITH-RUNTIME-SUBSCRIPTION-ID"`. Plus a `check "subscription_match"` block over `data.azurerm_client_config.current.subscription_id == var.subscription_id`. | [FR-002](spec.md#functional-requirements), [CA-011](spec.md#ca-011--subscription_id-runtime-injection-cli-or-env-corrects-c-005-quickstart-troubleshooting) |
| 2 | `topology` | `string` | **yes** | `contains(["hub","spoke"], var.topology)`. | [FR-003](spec.md#functional-requirements) |
| 3 | `tenant` | `string` | **yes** | regex `^(hub\|sp(0[1-9]\|[1-9][0-9]))$` AND cross-check (`var.topology=="hub"`⟺`var.tenant=="hub"`). Engine ALSO enforces `^(hub\|sp[0-9]{2})$` (`modules/naming/variables.tf` line 19). | [FR-003](spec.md#functional-requirements), [CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases) |
| 4 | `environment` | `string` | **yes** | `contains(["npd","prd"], var.environment)`. Engine enforces `^[a-z]{3}$`. | [FR-001](spec.md#functional-requirements) |
| 5 | `region` | `string` | **yes** | regex `^[a-z0-9]{3,4}$` at the stack boundary (engine repeats this AND enforces `INV-10` `contains(keys(module.catalogue.regions), var.input.region)` against the engine's internal catalogue). The consumer stack does NOT reference `module.catalogue` directly — `INV-10`'s failure message is the authoritative "unknown region" error. | [FR-004](spec.md#functional-requirements) |
| 6 | `usecase` | `string` | **yes** | regex `^[a-z0-9]{3}$`. **Tighter than the engine's `^[a-z0-9]{3,4}$`** so that the [CA-004 strategy-B fallback](spec.md#ca-004--per-entry-service_purpose-is-required-corrects-fr-005-planmd-r-2) (`service_purpose = coalesce(s.purpose, var.usecase)`) always produces a value that matches the engine's `service_purpose` regex `^[a-z0-9]{3}$`. Day-one value: `"shd"`. | [CA-002](spec.md#ca-002--usecase-is-the-8th-required-stack-input-corrects-fr-001-a2a5) |
| 7 | `repo` | `string` | **yes** | regex `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` AND length ≤ 256 (matches engine `var.input.repo` validation). | [FR-001](spec.md#functional-requirements) |
| 8 | `services` | `list(object({...}))` see § 2 | **yes** (MAY be `[]`) | per-entry validations in § 2. | [FR-005](spec.md#functional-requirements) |
| 9 | `overrides` | `map(map(any))` | optional (default `{}`) | keys forwarded verbatim; stack-side `check "overrides_keys_resolved"` enforces `keys(var.overrides) ⊆ keys(module.naming.names)` ([CA-006](spec.md#ca-006--stack-owns-unmatched-overrides-hard-fail-corrects-fr-006-fr-018-c-003)). | [FR-006](spec.md#functional-requirements) |

The stack's `stack_purpose` is **NOT an input** — it is hardcoded to `"svc"`
in `terraform/services/locals.tf`, mirroring
`terraform/vnet/locals.tf::naming_input.stack_purpose = "net"`.

---

## 2. `services[]` element schema

```hcl
list(object({
  type                = string                                      # required
  count               = optional(number, 1)                         # 0..999
  purpose             = optional(string)                            # default coalesce(.,var.usecase)
  overrides           = optional(map(any), {})                      # per-instance attribute map
  private_endpoints   = optional(list(any), [])                     # DEFERRED in v1 (A4) — non-empty hard-fails
  diagnostic_settings = optional(list(any), [])                     # DEFERRED in v1 (A4) — non-empty hard-fails
}))
```

Root-stack `variable "services"` validations:

| Field | Rule | Notes |
|---|---|---|
| `type` | `contains(local.v1_selectable_types, type)`. Friendly error citing the C-001 deferral table for non-allowlisted but engine-catalogued types; "unknown service type" for entirely unknown values. | [FR-007](spec.md#functional-requirements), [C-001](spec.md#clarifications), [CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases) |
| `count` | `count >= 0 && count <= 999`. `count == 0` silently skips the entry. | [FR-005](spec.md#functional-requirements); engine `INV-3` re-enforces ≤999 |
| `purpose` | `purpose == null \|\| can(regex("^[a-z0-9]{3}$", purpose))`. Default at the engine layer is `var.usecase` ([CA-004](spec.md#ca-004--per-entry-service_purpose-is-required-corrects-fr-005-planmd-r-2) strategy B; strategy A is opt-in by setting `purpose`). | [CA-004](spec.md#ca-004--per-entry-service_purpose-is-required-corrects-fr-005-planmd-r-2) |
| `private_endpoints` | `length(private_endpoints) == 0`. Else hard-fail with "private_endpoints deferred to follow-up; see spec.md A4." | [A4](spec.md#assumptions) |
| `diagnostic_settings` | `length(diagnostic_settings) == 0`. Else hard-fail with "diagnostic_settings deferred to follow-up; see spec.md A4." | [A4](spec.md#assumptions) |

`local.v1_selectable_types` enumerates exactly the 15 names from
[spec.md C-001](spec.md#clarifications):

```text
keyvault, storage, log_analytics, app_insights, container_registry,
user_assigned_identity, search, openai, aifoundry, language, doc_intel,
function_app, logic_app, aml_workspace, apim
```

The per-stack `resource_group` is NOT an operator-selectable entry — the
stack adds a single hardcoded `services[]` entry for it during expansion
(§ 3) so that `module.naming.names` returns the canonical RG name.

---

## 3. Stack→engine `services` expansion (`local.engine_services`)

The stack flattens `var.services` into engine records in three steps so
that (a) two operator entries that share `(type, purpose)` get distinct
engine keys (engine `INV-2` would otherwise hard-fail), and (b) the entire
expansion is invariant to re-ordering of `var.services` entries that share
`(type, purpose, count, overrides, ...)`:

```hcl
locals {
  # Step A — group operator entries by (type, purpose).
  _entries_by_group = {
    for s in var.services :
    format("%s|%s", s.type, coalesce(s.purpose, var.usecase)) => s...
  }

  # Step B — within each group, sort entries by their stable JSON
  # serialisation so a re-order of var.services that preserves the group
  # contents produces an identical sorted list.
  _sorted_entries_by_group = {
    for gk, entries in local._entries_by_group :
    gk => [for s_json in sort([for s in entries : jsonencode(s)]) : jsondecode(s_json)]
  }

  # Step C — assemble engine records. The synthetic `key` encodes both the
  # per-group entry index (within the sorted list) and the per-entry
  # instance number, so every key inside a (type, purpose) group is
  # unique by construction (engine INV-2 cannot fire).
  engine_services = concat(
    # one auto-emitted resource_group entry
    [{
      service_type    = "resource_group"
      service_purpose = null              # INV-4: forbidden on resource_group
      stack_purpose   = "svc"
      key             = "rg001"
      fqdn            = null
      extra_tags      = {}
    }],
    flatten([
      for gk in sort(keys(local._sorted_entries_by_group)) : flatten([
        for entry_idx, s in local._sorted_entries_by_group[gk] : [
          for n in range(1, s.count + 1) : {
            service_type    = s.type
            service_purpose = coalesce(s.purpose, var.usecase)   # INV-4: REQUIRED for non-RG, non-FQDN
            stack_purpose   = null                               # only meaningful for rg
            key             = format("%s%03d%03d", local.type_short[s.type], entry_idx + 1, n)
            fqdn            = null                               # forbidden for non-FQDN types
            extra_tags      = {}
          }
        ] if s.count > 0
      ])
    ]),
  )
}
```

`local.type_short` carries a per-type 3-letter slug derived from the
catalogue abbreviation (e.g. `keyvault → "key"`, `storage → "sto"`,
`log_analytics → "log"`). The synthetic key matches the engine regex
`^[a-z0-9]{1,16}$` (3-char slug + 3-digit entry-index + 3-digit instance =
9 chars). Because every key inside a `(service_type, service_purpose)`
group is the unique pair `(entry_idx, instance_n)`, engine `INV-2`
(duplicate-key detection) is impossible-by-construction even when
multiple operator entries share the same `(type, purpose)` (Spec C-002
explicitly supports this case).

The engine then SORTS each group by `key` ASC and assigns instance numbers
`001..N` — see `local.services_numbered` in
[modules/naming/locals.tf](../../modules/naming/locals.tf). The mapping
operator-order → instance-number is monotonic.

---

## 4. Engine record received by each wrapper module

For every `module "<type>" { for_each = ... }` invocation in
`terraform/services/main.tf`, the wrapper receives the per-instance value
from `module.naming.names[each.key]`:

```hcl
{
  service_type    = string            # always == "<type>"
  service_purpose = string             # the engine-resolved purpose
  stack_purpose   = string | null      # non-null only for resource_group
  parent          = string | null      # always null for top-level entries
  tags            = map(string)        # the merged baseline + extras (8 baseline keys)
  azure_max       = number             # catalogue azure_max for this type
}
```

The wrapper's `variable "engine_record"` MUST accept this shape verbatim
(re-validated at the wrapper boundary, per Constitution
defence-in-depth). The wrapper ALSO accepts:

| Wrapper input | Purpose |
|---|---|
| `canonical_name` | `each.key` from the stack — the engine-emitted canonical name. The wrapper passes this as the AVM module's `name` argument unaltered. |
| `resource_group_name` | The svc RG name. The wrapper sets the AVM's `resource_group_name` to this. |
| `location` | The engine's full region name. **Source**: read from the engine-emitted RG entry's tags, i.e. `module.naming.names[<rg_canonical_name>].tags.region` (the engine already resolves the short region code to the full Azure region via its internal `module.catalogue.regions`). The consumer stack does NOT reference `module.catalogue` directly — the engine's internal catalogue module is not re-exported as an output (only `engine_version` and `names` are public per [modules/naming/outputs.tf](../../modules/naming/outputs.tf)). |
| `overrides` | `lookup(var.overrides, each.key, {})` — the per-instance override map, merged on top of the wrapper's own defaults inside the AVM call ([CA-005](spec.md#ca-005--per-service-defaults-are-wrapper-owned-corrects-fr-013-a9-c-007-data-model--8)). |

---

## 5. Canonical-name catalogue for v1 selectable types

Verified against `local.top_level_named` in
[modules/naming/locals.tf](../../modules/naming/locals.tf) using the
reference invocation `(stack_purpose="svc", usecase="shd",
service_purpose="shd")`. The format strings below are literal copies of the
engine's `format(...)` calls in lines 137–198.

For `(tenant="sp01", environment="npd", region="uks")`:

| Type | Engine shape | Canonical name (reference) | `azure_max` |
|---|---|---|---|
| `resource_group` | `rg-{stack_purpose}-{usecase}-{tenant}-{env}-{region}-{instance}` | `rg-svc-shd-sp01-npd-uks-001` | 90 |
| `keyvault` | `kv{p}{usecase}{tenant}{env}{region}{instance}` | `kvshdshdsp01npduks001` (len 21) | 24 |
| `storage` | `st{p}{usecase}{tenant}{env}{region}{instance}` | `stshdshdsp01npduks001` (len 21) | 24 |
| `container_registry` | `cr{p}{usecase}{tenant}{env}{region}{instance}` | `crshdshdsp01npduks001` (len 21) | 50 |
| `log_analytics` | `log-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `log-shd-shd-sp01-npd-uks-001` (len 28) | 63 |
| `app_insights` | `appi-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `appi-shd-shd-sp01-npd-uks-001` (len 29) | 260 |
| `user_assigned_identity` | `id-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `id-shd-shd-sp01-npd-uks-001` (len 27) | 128 |
| `search` | `srch-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `srch-shd-shd-sp01-npd-uks-001` (len 29) | 60 |
| `openai` | `oai-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `oai-shd-shd-sp01-npd-uks-001` (len 28) | 64 |
| `aifoundry` | `aif-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `aif-shd-shd-sp01-npd-uks-001` (len 28) | 64 |
| `language` | `lang-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `lang-shd-shd-sp01-npd-uks-001` (len 29) | 64 |
| `doc_intel` | `di-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `di-shd-shd-sp01-npd-uks-001` (len 27) | 64 |
| `function_app` | `func-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `func-shd-shd-sp01-npd-uks-001` (len 29) | 60 |
| `logic_app` | `logic-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `logic-shd-shd-sp01-npd-uks-001` (len 30) | 80 |
| `aml_workspace` | `mlw-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `mlw-shd-shd-sp01-npd-uks-001` (len 28) | 33 |
| `apim` | `apim-{p}-{usecase}-{tenant}-{env}-{region}-{instance}` | `apim-shd-shd-sp01-npd-uks-001` (len 29) | 50 |

For `(topology=hub, tenant="hub", environment="npd", region="uks")`,
substitute `hub` for `sp01` in every position. Example: the hub RG becomes
`rg-svc-shd-hub-npd-uks-001`.

Every name above is verified to satisfy engine `INV-6` (length ≤ `azure_max`)
and `INV-7` (charset matches `^[a-z0-9.-]+$`).

---

## 6. Baseline tag set (engine output `tags`)

Verified against `local.baseline_tag_keys` in
[modules/naming/locals.tf](../../modules/naming/locals.tf) lines 18–27.
The engine emits EIGHT baseline keys on every top-level resource:

```text
tenant
environment
region            # NB: the FULL region name, e.g. "uksouth" (not the short code "uks")
managed_by        # always literal "terraform"
repo
usecase
stack_purpose
service_purpose
```

For the reference invocation, every emitted resource carries:

```hcl
{
  tenant          = "sp01"
  environment     = "npd"
  region          = "uksouth"        # lookup(module.catalogue.regions, "uks")
  managed_by      = "terraform"
  repo            = "tcsatheesh/tfiac"
  usecase         = "shd"
  stack_purpose   = "svc"            # except for resource_group entries where it equals the entry's stack_purpose (also "svc" here)
  service_purpose = "shd"            # except for resource_group entries where it equals stack_purpose
}
```

Per-instance additive tags ride on the engine's per-entry `extra_tags`
slot; the engine MERGES `{baseline, var.extra_tags, entry.extra_tags}` with
last-writer-wins, and `INV-8` hard-fails any attempt to OVERWRITE a
baseline key via either `extra_tags` channel.

---

## 7. `overrides` (top-level) map shape

```hcl
map(map(any))
```

Example:

```hcl
overrides = {
  "kvshdshdsp01npduks001"          = { sku_name = "premium" }
  "log-shd-shd-sp01-npd-uks-001"   = { retention_in_days = 90 }
}
```

Key contract: every key MUST equal an engine-emitted canonical name in
`module.naming.names`. Stack `check "overrides_keys_resolved"` block
hard-fails at plan time listing every unmatched key
([CA-006](spec.md#ca-006--stack-owns-unmatched-overrides-hard-fail-corrects-fr-006-fr-018-c-003)).

---

## 8. Per-service defaults (wrapper-owned)

The stack does **not** maintain a `local.defaults[type]` map (CA-005). Each
wrapper module owns its own defaults in
`modules/<service>/locals.tf::defaults` and merges the operator's
`overrides` map on top inside its single AVM invocation. The wrapper's
README documents the default values.

The engine has NO defaults map. Any prior reference to
`local.defaults[type]` or "engine per-service default RBAC bindings" is
fictional ([CA-005](spec.md#ca-005--per-service-defaults-are-wrapper-owned-corrects-fr-013-a9-c-007-data-model--8)).
