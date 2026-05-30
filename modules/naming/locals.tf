# Naming Convention Engine - core transform.
# Inputs (var.input, var.services, var.children, var.extra_tags)
# are validated by variable-level `validation` blocks and the
# cross-field preconditions in check.tf. This file is pure HCL
# data-flow; do not introduce randomness or list-index keys.
#
# Determinism contract (SC-003):
#   - local.services_numbered iterates a list sorted by (service_type,
#     service_purpose|stack_purpose, key); file order of var.services
#     is irrelevant.
#   - local.children_numbered iterates a list sorted by (service_type,
#     parent_key, key).
#   - Map outputs (output "names") iterate alphabetically by key
#     (HCL guarantee on maps).

locals {
  # ----- Baseline tag-key set (INV-8 collision detection) -----
  baseline_tag_keys = [
    "tenant",
    "environment",
    "region",
    "managed_by",
    "repo",
    "usecase",
    "stack_purpose",
    "service_purpose",
  ]

  # ----- Catalogue helpers -----
  service_types_known = keys(module.catalogue.services)
  top_level_types     = [for k, v in module.catalogue.services : k if v.level == "top"]
  child_types         = [for k, v in module.catalogue.services : k if v.level == "child"]
  fqdn_types          = [for k, v in module.catalogue.services : k if v.shape == "fqdn"]

  # ----- Per-entry validation helpers (consumed by check.tf preconditions) -----

  # INV-1: unknown service_type in services / children.
  services_unknown_types = [
    for s in var.services : s.service_type
    if !contains(local.service_types_known, s.service_type) || !contains(local.top_level_types, s.service_type)
  ]
  children_unknown_types = [
    for c in var.children : c.service_type
    if !contains(local.service_types_known, c.service_type) || !contains(local.child_types, c.service_type)
  ]

  # INV-4: RG shape - rg entries forbid service_purpose; non-RG, non-FQDN entries require it.
  services_rg_shape_violations = [
    for s in var.services : s.key
    if(
      s.service_type == "resource_group"
      ? s.service_purpose != null
      : (
        !contains(local.fqdn_types, s.service_type)
        && s.service_purpose == null
      )
    )
  ]

  # INV-10: input.region must be in the region catalogue.
  region_known = contains(keys(module.catalogue.regions), var.input.region)

  # INV-8: var.extra_tags must not collide with baseline keys; per-entry extra_tags likewise.
  stack_extra_tags_collisions = [
    for k in keys(var.extra_tags) : k
    if contains(local.baseline_tag_keys, k)
  ]
  entry_extra_tags_collisions = flatten([
    for s in var.services : [
      for k in keys(s.extra_tags) : "services[${s.key}].${k}"
      if contains(local.baseline_tag_keys, k)
    ]
  ])
  child_extra_tags_collisions = flatten([
    for c in var.children : [
      for k in keys(c.extra_tags) : "children[${c.key}].${k}"
      if contains(local.baseline_tag_keys, k)
    ]
  ])

  # ----- Top-level grouping and numbering -----

  # Grouping key includes service_purpose for non-RG, stack_purpose for RG.
  # (FQDN entries also get grouped by service_purpose so they share the
  # same uniqueness scope as other named entries; their canonical name
  # is the FQDN, not the numbered tuple.)
  services_with_group = [
    for s in var.services : merge(s, {
      _group_key = format(
        "%s|%s",
        s.service_type,
        s.service_type == "resource_group"
        ? coalesce(s.stack_purpose, var.input.stack_purpose)
        : coalesce(s.service_purpose, "_")
      )
    })
  ]

  services_grouped = {
    for s in local.services_with_group : s._group_key => s...
  }

  # INV-2: duplicate (service_type, service_purpose, key).
  duplicate_key_groups = [
    for gk, group in local.services_grouped : gk
    if length(group) != length(distinct([for s in group : s.key]))
  ]

  # INV-3: per-group count <= 999.
  oversize_groups = [
    for gk, group in local.services_grouped : "${gk} (${length(group)})"
    if length(group) > 999
  ]

  # Number entries: sort each group by key, assign 001, 002, ...
  services_numbered = flatten([
    for gk in sort(keys(local.services_grouped)) : [
      for idx, key in sort([for s in local.services_grouped[gk] : s.key]) :
      merge(
        [for s in local.services_grouped[gk] : s if s.key == key][0],
        { instance = format("%03d", idx + 1) }
      )
    ]
  ])

  # ----- Top-level name composition -----

  # Filter out entries with unknown service_type so the catalogue lookup
  # below does not crash before INV-1 precondition fires.
  services_numbered_safe = [
    for e in local.services_numbered : e
    if contains(local.service_types_known, e.service_type)
    && contains(local.top_level_types, e.service_type)
  ]

  # The hyphenated "parent tuple" form, used as {P} when this entry is
  # referenced as a child's parent. For RG this is the rg-specific shape.
  top_level_named = [
    for entry in local.services_numbered_safe : merge(entry, {
      canonical_name = (
        module.catalogue.services[entry.service_type].shape == "rg_hyphenated" ?
        format(
          "rg-%s-%s-%s-%s-%s-%s",
          coalesce(entry.stack_purpose, var.input.stack_purpose),
          var.input.usecase,
          var.input.tenant,
          var.input.environment,
          var.input.region,
          entry.instance,
        ) :
        module.catalogue.services[entry.service_type].shape == "hyphenated" ?
        format(
          "%s-%s-%s-%s-%s-%s-%s",
          module.catalogue.services[entry.service_type].abbr,
          entry.service_purpose != null ? entry.service_purpose : "x",
          var.input.usecase,
          var.input.tenant,
          var.input.environment,
          var.input.region,
          entry.instance,
        ) :
        module.catalogue.services[entry.service_type].shape == "concatenated" ?
        format(
          "%s%s%s%s%s%s%s",
          module.catalogue.services[entry.service_type].abbr,
          entry.service_purpose != null ? entry.service_purpose : "x",
          var.input.usecase,
          var.input.tenant,
          var.input.environment,
          var.input.region,
          entry.instance,
        ) :
        module.catalogue.services[entry.service_type].shape == "fqdn" ?
        coalesce(entry.fqdn, "MISSING_FQDN") :
        "UNKNOWN_SHAPE"
      )
      parent_tuple = (
        module.catalogue.services[entry.service_type].shape == "rg_hyphenated" ?
        format(
          "rg-%s-%s-%s-%s-%s-%s",
          coalesce(entry.stack_purpose, var.input.stack_purpose),
          var.input.usecase,
          var.input.tenant,
          var.input.environment,
          var.input.region,
          entry.instance,
        ) :
        module.catalogue.services[entry.service_type].shape == "fqdn" ?
        "" :
        format(
          "%s-%s-%s-%s-%s-%s-%s",
          module.catalogue.services[entry.service_type].abbr,
          entry.service_purpose != null ? entry.service_purpose : "x",
          var.input.usecase,
          var.input.tenant,
          var.input.environment,
          var.input.region,
          entry.instance,
        )
      )
    })
  ]

  # ----- Parent tuple lookup by caller-supplied key -----
  # Use grouping then take-first so duplicate keys do not crash here;
  # parent_key uniqueness is enforced separately via preconditions.
  parent_lookup_by_key = {
    for k, items in { for e in local.top_level_named : e.key => e... } : k => {
      service_type   = items[0].service_type
      canonical_name = items[0].canonical_name
      parent_tuple   = items[0].parent_tuple
    }
  }

  # ----- Child validation (consumed by check.tf preconditions) -----

  # Parent key must resolve to a known top-level entry.
  children_unknown_parents = [
    for c in var.children : c.parent_key
    if !contains(keys(local.parent_lookup_by_key), c.parent_key)
  ]

  # Parent type must match the child catalogue's parent_type (or "*").
  children_parent_type_mismatches = [
    for c in var.children : format("%s/%s", c.service_type, c.parent_key)
    if(
      contains(keys(local.parent_lookup_by_key), c.parent_key)
      && contains(local.child_types, c.service_type)
      && module.catalogue.services[c.service_type].parent_type != "*"
      && module.catalogue.services[c.service_type].parent_type != local.parent_lookup_by_key[c.parent_key].service_type
    )
  ]

  # child_purpose required for shape=child_purpose; forbidden for singleton/positional.
  children_purpose_violations = [
    for c in var.children : format("%s/%s", c.service_type, c.key)
    if(
      contains(local.child_types, c.service_type)
      && (
        (module.catalogue.services[c.service_type].shape == "child_purpose" && c.child_purpose == null)
        ||
        (module.catalogue.services[c.service_type].shape != "child_purpose" && c.child_purpose != null)
      )
    )
  ]

  # ----- Child grouping and numbering -----

  children_with_group = [
    for c in var.children : merge(c, {
      _group_key = format("%s|%s", c.service_type, c.parent_key)
    })
    if contains(local.child_types, c.service_type)
    && contains(keys(local.parent_lookup_by_key), c.parent_key)
  ]

  children_grouped = {
    for c in local.children_with_group : c._group_key => c...
  }

  # INV-5: singletons must have at most 1 entry per (child_type, parent_key).
  singleton_overflow = [
    for gk, group in local.children_grouped : gk
    if length(group) > 1
    && module.catalogue.services[group[0].service_type].shape == "singleton"
  ]

  # Duplicate key within (child_type, parent_key) group.
  duplicate_child_key_groups = [
    for gk, group in local.children_grouped : gk
    if length(group) != length(distinct([for c in group : c.key]))
  ]

  # Child positional numbering.
  children_numbered = flatten([
    for gk in sort(keys(local.children_grouped)) : [
      for idx, key in sort([for c in local.children_grouped[gk] : c.key]) :
      merge(
        [for c in local.children_grouped[gk] : c if c.key == key][0],
        { instance = format("%03d", idx + 1) }
      )
    ]
  ])

  # ----- Child name composition -----

  child_named = [
    for entry in local.children_numbered : merge(entry, {
      canonical_name = (
        module.catalogue.services[entry.service_type].shape == "child_purpose" ?
        format(
          "%s-%s-%s",
          module.catalogue.services[entry.service_type].abbr,
          coalesce(entry.child_purpose, "x"),
          local.parent_lookup_by_key[entry.parent_key].parent_tuple,
        ) :
        module.catalogue.services[entry.service_type].shape == "singleton" ?
        format(
          "%s-%s",
          module.catalogue.services[entry.service_type].abbr,
          local.parent_lookup_by_key[entry.parent_key].parent_tuple,
        ) :
        module.catalogue.services[entry.service_type].shape == "positional" ?
        format(
          "%s-%s-%s",
          module.catalogue.services[entry.service_type].abbr,
          local.parent_lookup_by_key[entry.parent_key].parent_tuple,
          entry.instance,
        ) :
        "UNKNOWN_CHILD_SHAPE"
      )
      parent_canonical_name = local.parent_lookup_by_key[entry.parent_key].canonical_name
    })
  ]

  # ----- Per-entry baseline tags + merging -----

  # Baseline tag map for a top-level entry. Group-and-take-first so
  # duplicate canonical_name does not crash here; INV-2/INV-7 collisions
  # are surfaced by preconditions.
  top_level_tags = {
    for k, items in { for e in local.top_level_named : e.canonical_name => e... } :
    k => merge(
      {
        tenant          = var.input.tenant
        environment     = var.input.environment
        region          = lookup(module.catalogue.regions, var.input.region, var.input.region)
        managed_by      = "terraform"
        repo            = var.input.repo
        usecase         = var.input.usecase
        stack_purpose   = items[0].service_type == "resource_group" ? coalesce(items[0].stack_purpose, var.input.stack_purpose) : var.input.stack_purpose
        service_purpose = items[0].service_type == "resource_group" ? coalesce(items[0].stack_purpose, var.input.stack_purpose) : (items[0].service_purpose != null ? items[0].service_purpose : "")
      },
      var.extra_tags,
      items[0].extra_tags,
    )
  }

  # Baseline tag map for a child entry. Child inherits the parent's
  # (usecase, tenant, environment, region) via the global var.input
  # (which is the same source). service_purpose for children is the
  # child's catalogue abbr suffix; we use the parent's service_purpose
  # for tagging coherence.
  child_tags = {
    for k, items in { for c in local.child_named : c.canonical_name => c... } :
    k => merge(
      {
        tenant          = var.input.tenant
        environment     = var.input.environment
        region          = lookup(module.catalogue.regions, var.input.region, var.input.region)
        managed_by      = "terraform"
        repo            = var.input.repo
        usecase         = var.input.usecase
        stack_purpose   = var.input.stack_purpose
        service_purpose = module.catalogue.services[items[0].service_type].abbr
      },
      var.extra_tags,
      items[0].extra_tags,
    )
  }

  # ----- Merged output map -----

  top_level_output = {
    for k, items in { for e in local.top_level_named : e.canonical_name => e... } :
    k => {
      service_type    = items[0].service_type
      service_purpose = items[0].service_purpose
      stack_purpose   = items[0].service_type == "resource_group" ? coalesce(items[0].stack_purpose, var.input.stack_purpose) : null
      parent          = null
      tags            = local.top_level_tags[k]
      azure_max       = module.catalogue.services[items[0].service_type].azure_max
    }
  }

  child_output = {
    for k, items in { for c in local.child_named : c.canonical_name => c... } :
    k => {
      service_type    = items[0].service_type
      service_purpose = null
      stack_purpose   = null
      parent          = items[0].parent_canonical_name
      tags            = local.child_tags[k]
      azure_max       = module.catalogue.services[items[0].service_type].azure_max
    }
  }

  all_names = merge(local.top_level_output, local.child_output)
}
