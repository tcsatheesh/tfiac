# Phase 1 Data Model: Naming Convention Engine

The engine has **no persisted state**. The "data model" below describes
the in-memory shapes that flow through the module at `terraform plan`
time. All shapes are HCL object types.

## Inputs

### `var.input` (stack-level)

```hcl
input = object({
  tenant          = string  # ^(hub|sp[0-9]{2})$
  environment     = string  # ^[a-z]{3}$
  region          = string  # CAF short code, present in catalogue.regions
  usecase         = string  # ^[a-z0-9]{3,4}$
  stack_purpose   = string  # ^[a-z0-9]{3}$
  repo            = string  # github_org/github_repo, ≤256 chars
})
```

Each field is validated by a `validation { ... }` block on the
variable. Region is additionally cross-checked against
`local.regions` in a `precondition`.

### `var.services` (list of top-level service entries)

```hcl
services = list(object({
  service_type    = string                       # must be a key in local.services AND a top-level row
  service_purpose = optional(string)             # required for non-RG; forbidden for RG
  stack_purpose   = optional(string)             # required for RG; forbidden for non-RG
  key             = string                       # ^[a-z0-9]{1,16}$, unique within (service_type, service_purpose)
  fqdn            = optional(string)             # required IFF service_type in {dns_zone, private_dns_zone}; ^[a-z0-9.-]{1,253}$
  extra_tags      = optional(map(string), {})    # per-entry additive; overrides stack-level extra_tags for the same non-baseline key
}))
```

Note: an RG entry uses the stack-level `var.input.stack_purpose` by
default; the per-entry `stack_purpose` field is reserved for stacks
that compose multiple RGs (e.g. a stack with `dns` + `log` RGs).

### `var.children` (list of child entries)

```hcl
children = list(object({
  service_type     = string  # must be a child row in catalogue
  parent_key       = string  # = `key` of a top-level entry above
  child_purpose    = optional(string)  # required for purpose-keyed children; forbidden for singletons/positional
  key              = string  # ^[a-z0-9]{1,16}$, unique within (child_type, parent, ...)
  extra_tags       = optional(map(string), {})
}))
```

### `var.extra_tags` (stack-level)

```hcl
extra_tags = map(string)  # additive only; collision with baseline key fails loudly
```

## Internal locals

### `local.services` (catalogue)

```hcl
local.services = {
  # top-level
  "resource_group"   = { abbr = "rg",   shape = "hyphenated",   azure_max = 90,  level = "top", rg_special = true }
  "vnet"             = { abbr = "vnet", shape = "hyphenated",   azure_max = 64,  level = "top" }
  # ... 24 more top-level rows (26 top-level rows total per spec table)
  "storage"          = { abbr = "st",   shape = "concatenated", azure_max = 24,  level = "top" }
  # ...
  # children
  "subnet"           = { abbr = "snet",    shape = "child_purpose", level = "child", parent_type = "vnet" }
  "vnet_bastion"     = { abbr = "bas",     shape = "singleton",     level = "child", parent_type = "vnet" }
  "vnet_firewall"    = { abbr = "afw",     shape = "singleton",     level = "child", parent_type = "vnet" }
  "private_endpoint" = { abbr = "pep",     shape = "positional",    level = "child", parent_type = "*" }
  # ...
}
```

The `shape` field drives composition:

| `shape`          | Format                                              |
|------------------|-----------------------------------------------------|
| `hyphenated`     | `{abbr}-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}` |
| `concatenated`   | `{abbr}{p}{usecase}{tenant}{environment}{region}{instance}` |
| `rg_hyphenated`  | `rg-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}` |
| `fqdn`           | passthrough; validated against `^[a-z0-9.-]{1,253}$` |
| `child_purpose`  | `{abbr}-{child_purpose}-{P}` |
| `singleton`      | `{abbr}-{P}` |
| `positional`     | `{abbr}-{P}-{instance}` |

### `local.regions` (catalogue)

```hcl
local.regions = {
  uks  = "uksouth"
  weu  = "westeurope"
  eus2 = "eastus2"
  # ... grows as needed
}
```

### `local.numbered_services`

A list of top-level entries augmented with engine-assigned `instance`,
produced by:

1. Sort `var.services` by `(service_type, service_purpose, key)`.
2. Group by `(service_type, service_purpose)`.
3. Within each group, assign `instance = format("%03d", n + 1)`.
4. `precondition`: max `999` per group; no duplicate `key` per group.

### `local.numbered_children`

Same shape for children, with positional numbering scoped by
`(child_type, parent_canonical_name, key)`. Singletons get no
`instance`; their `precondition` enforces max 1 per parent.

## Outputs

### `output "names"`

```hcl
output "names" = {
  "<canonical_name>" = {
    service_type     = string
    service_purpose  = optional(string)
    stack_purpose    = optional(string)
    parent           = optional(string)   # canonical_name of parent for child entries
    tags             = map(string)        # baseline + extra_tags
    azure_max        = number             # for downstream sanity checks
  }
  # ... one entry per resource
}
```

Map iteration order is alphabetical by key (canonical name); HCL
guarantees this for `output` of a `map` type, satisfying SC-003.

## Invariants (asserted by `precondition` / `postcondition`)

| ID  | Invariant                                                                 | Where                  |
|-----|---------------------------------------------------------------------------|------------------------|
| INV-1 | Every `service_type` in inputs is a key in `local.services`.            | `locals.tf` precond    |
| INV-2 | `key` is unique within `(service_type, service_purpose)`.               | `locals.tf` precond    |
| INV-3 | Per-group `instance` ≤ `999`.                                           | `locals.tf` precond    |
| INV-4 | RG entries have `stack_purpose`, no `service_purpose`. Inverse for others. | `locals.tf` precond  |
| INV-5 | Singleton children: ≤ 1 per parent.                                     | `locals.tf` precond    |
| INV-6 | Each computed name fits within its `azure_max`.                         | `outputs.tf` postcond  |
| INV-7 | Each computed name matches the regex implied by its shape.              | `outputs.tf` postcond  |
| INV-8 | `var.extra_tags` shares no key with the baseline tag set.               | `locals.tf` precond    |
| INV-9 | Every emitted tag value ≤ 256 chars and key ≤ 512 chars.                | `outputs.tf` postcond  |
| INV-10 | `var.input.region` is a key in `local.regions`.                        | `locals.tf` precond    |
