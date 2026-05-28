###############################################################################
# Locals — staged transformations
#
# Stage 1  parsed             flatten services + children
# Stage 2  validated          (no-op shape; rules live in validate.tf)
# Stage 3  numbered           assign per-(type, batch) and per-(child, parent)
#                             instance numbers
# Stage 4  shaped             carry hyphen rule + segments
# Stage 5  named              render canonical_name per FR-016 shapes
# Stage 5b resource_group     emit the per-stack RG record (FR-025)
# Stage 6  override_merge     attach record.defaults and record.overrides
# Stage 6b tags               build baseline tags + merge override tags
# Stage 7  emitted            final flat map keyed by canonical_name
###############################################################################

locals {
  # Convenience.
  region_code     = lookup(local.region_codes, var.input.region, "INVALID_REGION")
  rg_canonical    = "rg-${var.input.tenant}-${var.input.environment}-${local.region_code}-001"
  child_type_keys = keys(local.child_types)

  # ─── Stage 1 — parsed ──────────────────────────────────────────────────────
  # Flatten the input into a single list of intent records.
  # raw_index encodes stable ordering for deterministic numbering (FR-008).

  # Filter zero-count entries (FR-039) but keep their slots so subsequent
  # entries of the same type still number from where they would naturally land.
  parsed_top_level = flatten([
    for s_idx, svc in var.input.services : [
      for inst_pos in range(coalesce(svc.count, 1)) : {
        type           = svc.type
        parent_ref     = null
        parent_type    = null
        purpose        = null
        pe_subnet      = null
        raw_index      = s_idx * 1000 + inst_pos
        svc_index      = s_idx
        inst_pos       = inst_pos
        is_child       = false
        child_type_key = null
        spec           = svc
      }
    ]
  ])

  parsed_children = flatten([
    for s_idx, svc in var.input.services : flatten([
      for child_type, ct in local.child_types : [
        for c_idx, c in lookup(svc, ct.child_list_key, []) : {
          type        = child_type
          parent_ref  = s_idx
          parent_type = svc.type
          # purpose-keyed children carry a "purpose"; positional children carry
          # null. Positional PEs additionally carry a pe_subnet reference.
          purpose        = ct.numbering == "purpose-keyed" ? c.purpose : null
          pe_subnet      = child_type == "private_endpoint" ? c.subnet : null
          raw_index      = 1000000 + s_idx * 10000 + index(local.child_type_keys, child_type) * 1000 + c_idx
          svc_index      = s_idx
          inst_pos       = c_idx
          is_child       = true
          child_type_key = ct.child_list_key
          spec           = c
        }
      ]
    ])
  ])

  parsed = concat(local.parsed_top_level, local.parsed_children)

  # ─── Stage 2 — validated ───────────────────────────────────────────────────
  # Rules live in validate.tf as check {} blocks. The parsed shape is unchanged.
  validated = local.parsed

  # ─── Stage 3 — numbered ────────────────────────────────────────────────────
  # Top-level: instance = 1 + position-among-records-of-this-type-in-this-stack.
  # Positional children: instance = 1 + position-among-records-of-this-child-type-under-this-parent-svc-index.
  # Purpose-keyed children: instance = null.

  # Pre-compute index lookups using sorted raw_index per group.
  top_level_by_type = {
    for t in toset([for r in local.validated : r.type if !r.is_child]) :
    t => [for r in local.validated : r.raw_index if !r.is_child && r.type == t]
  }

  positional_children_by_group = {
    for grp in toset([
      for r in local.validated : "${r.parent_ref}|${r.type}"
      if r.is_child && lookup(local.child_types, r.type, { numbering = "" }).numbering == "positional"
    ]) :
    grp => [
      for r in local.validated : r.raw_index
      if r.is_child && "${r.parent_ref}|${r.type}" == grp
    ]
  }

  numbered = [
    for r in local.validated : merge(r, {
      instance = (
        !r.is_child
        ? index(local.top_level_by_type[r.type], r.raw_index) + 1
        : (
          lookup(local.child_types, r.type, { numbering = "" }).numbering == "positional"
          ? index(local.positional_children_by_group["${r.parent_ref}|${r.type}"], r.raw_index) + 1
          : null
        )
      )
    })
  ]

  # ─── Stage 4 — shaped ──────────────────────────────────────────────────────
  shaped = [
    for r in local.numbered : merge(r, {
      caf_abbr = (
        r.is_child
        ? local.child_types[r.type].caf_abbr
        : lookup(local.services, r.type, { caf_abbr = "UNKNOWN" }).caf_abbr
      )
      shape = (
        r.is_child
        # Children inherit hyphen rule from parent.
        ? lookup(local.services, r.parent_type, { shape = "hyphenated" }).shape
        : lookup(local.services, r.type, { shape = "hyphenated" }).shape
      )
      region_code_segment = local.region_code
      tenant_segment      = var.input.tenant
      env_segment         = var.input.environment
      instance_segment    = format("%03d", coalesce(r.instance, 1))
    })
  ]

  # ─── Stage 5 — named ───────────────────────────────────────────────────────
  # Top-level records first, then children that reference top-level canonical
  # names. Two passes via a map keyed by raw_index.

  top_level_named = {
    for r in local.shaped : r.raw_index => merge(r, {
      canonical_name = (
        r.shape == "hyphenated"
        ? "${r.caf_abbr}-${r.tenant_segment}-${r.env_segment}-${r.region_code_segment}-${r.instance_segment}"
        : "${r.caf_abbr}${r.tenant_segment}${r.env_segment}${r.region_code_segment}${r.instance_segment}"
      )
      parent_canonical = null
    }) if !r.is_child
  }

  children_named = {
    for r in local.shaped : r.raw_index => merge(r, {
      canonical_name = (
        r.shape == "hyphenated" && lookup(local.child_types, r.type, { numbering = "" }).numbering == "purpose-keyed"
        ? "${r.caf_abbr}-${coalesce(r.purpose, "x")}-${r.tenant_segment}-${r.env_segment}-${r.region_code_segment}-${format("%03d", lookup(local.top_level_named, r.parent_ref, { instance = 1 }).instance)}"
        : (
          r.shape == "hyphenated"
          ? "${r.caf_abbr}-${r.tenant_segment}-${r.env_segment}-${r.region_code_segment}-${format("%03d", lookup(local.top_level_named, r.parent_ref, { instance = 1 }).instance)}-${r.instance_segment}"
          : "${r.caf_abbr}${r.tenant_segment}${r.env_segment}${r.region_code_segment}${format("%03d", lookup(local.top_level_named, r.parent_ref, { instance = 1 }).instance)}${r.instance_segment}"
        )
      )
      parent_canonical = lookup(local.top_level_named, r.parent_ref, { canonical_name = null }).canonical_name
    }) if r.is_child
  }

  named = concat(values(local.top_level_named), values(local.children_named))

  # ─── Stage 5b — resource group ────────────────────────────────────────────
  rg_record = {
    canonical_name   = local.rg_canonical
    type             = "resource_group"
    is_child         = false
    parent_canonical = null
    parent_type      = null
    instance         = 1
    purpose          = null
    pe_subnet        = null
    shape            = "hyphenated"
    caf_abbr         = "rg"
  }

  named_with_rg = concat([local.rg_record], local.named)

  # ─── Stage 6 — defaults & overrides ───────────────────────────────────────
  override_merged = [
    for r in local.named_with_rg : merge(r, {
      defaults  = lookup(local.defaults, r.type, {})
      overrides = try(var.input.overrides[r.canonical_name], {})
    })
  ]

  # ─── Stage 6b — tags ──────────────────────────────────────────────────────
  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }

  tagged_records = [
    for r in local.override_merged : merge(r, {
      tags = merge(
        local.baseline_tags,
        try(tomap(var.input.overrides[r.canonical_name].tags), {})
      )
    })
  ]

  # ─── Stage 7 — emitted ────────────────────────────────────────────────────
  # NOTE: use merge() of one-key maps so duplicate canonical names do NOT raise
  # a hard for-expression error — they are surfaced by check.shape_regex /
  # check.purpose_unique_per_parent instead, producing actionable messages.
  emitted = merge([
    for r in local.tagged_records : {
      (r.canonical_name) = {
        service_type   = r.type
        topology       = var.input.topology
        tenant         = var.input.tenant
        environment    = var.input.environment
        region         = var.input.region
        instance       = r.instance
        purpose        = r.purpose
        parent         = r.parent_canonical
        resource_group = r.type == "resource_group" ? r.canonical_name : local.rg_canonical
        tags           = r.tags
        defaults       = r.defaults
        overrides      = r.overrides
      }
    }
  ]...)
}
