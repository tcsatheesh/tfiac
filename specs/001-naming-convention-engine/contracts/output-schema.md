# Contract: outputs `names` and `by_type`

The engine emits **two** top-level outputs and nothing else.

## `output "names"` (primary)

Flat map keyed by canonical resource name. Consumers iterate it
directly via `for_each = module.naming.names` (filtered as needed).

```hcl
output "names" {
  description = "Flat map of every canonical resource name produced for this batch."

  value = {
    "<canonical_name>" = {
      service_type   = string           # e.g. "vnet", "storage", "subnet"
      topology       = string           # echoes input.topology
      tenant         = string           # echoes input.tenant
      environment    = string           # echoes input.environment
      region         = string           # echoes input.region (full Azure region name)
      instance       = number | null    # null for purpose-keyed children
      purpose        = string | null    # null for non-purpose records
      parent         = string | null    # canonical name of parent; null for top-level + RG
      resource_group = string           # always the per-stack RG canonical name (FR-025)
      tags           = map(string)      # baseline merged with overrides[canonical_name]
      defaults       = map(any)         # local.defaults[service_type]
      overrides      = map(any)         # var.input.overrides[canonical_name] or {}
    }
    # ... one entry per resource the consumer must declare
  }
}
```

### Key invariants

- The map key equals `record.canonical_name`.
- The map key is the **only** value a downstream module may pass to
  `for_each`; passing a list index is forbidden (FR-007).
- The per-stack RG record always appears, keyed by
  `rg-{tenant}-{environment}-{region_code}-001` (or its concatenated
  form if the catalogue ever marks `resource_group` as hyphen-
  forbidden, which it does not on day one).
- For top-level records other than the RG, `parent == null` and
  `resource_group` points at the RG's canonical name.
- For child records, `parent` points at the parent's canonical name
  and `resource_group` still points at the per-stack RG.

## `output "by_type"` (convenience index)

```hcl
output "by_type" {
  description = "Convenience index: service_type → list of canonical names."

  value = {
    "<service_type>" = ["<canonical_name>", ...]
    # ... one entry per service_type that appears in this batch
  }
}
```

Equivalent to
`{ for n, r in output.names : r.service_type => n... }`. Useful when a
consumer module wants to declare resources of exactly one type without
filtering the full `names` map.

## Determinism contract (FR-006 / SC-003)

- Identical `var.input` MUST produce a byte-identical
  `output "names"` value on every invocation.
- Iteration order is irrelevant for HCL maps; equality is by key/value
  set.
- The committed snapshot at
  `modules/naming/tests/snapshots/reference.json` is the canonical
  reference for the regression gate.

## Consumer pattern (example)

```hcl
# In a downstream module:
resource "azurerm_virtual_network" "this" {
  for_each = {
    for n, r in module.naming.names : n => r if r.service_type == "vnet"
  }

  name                = each.key
  resource_group_name = each.value.resource_group
  location            = each.value.region
  address_space       = lookup(each.value.overrides, "address_space",
                               each.value.defaults.address_space)
  tags                = each.value.tags
}
```

The downstream module never constructs a name. It receives one,
applies it, and tags accordingly.

## What the engine does NOT emit

- No provider configuration.
- No state.
- No secret values.
- No address spaces, CIDR allocations, or IP plans (defaulted, but
  not allocated dynamically — that is a future spec).
- No role-assignment names (handled by the existing RBAC module's
  UUIDv5 derivation — see Constitution Principle VIII; left untouched
  by this feature).
