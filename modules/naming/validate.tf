###############################################################################
# Module-level check {} blocks — plan-time hard errors (FR-016..FR-039).
#
# Every block emits an empty assertion when valid; on violation it raises a
# diagnostic that names the offending input AND remediation guidance.
###############################################################################

# ─── FR-018 — known region ────────────────────────────────────────────────────
check "region_known" {
  assert {
    condition     = contains(keys(local.region_codes), var.input.region)
    error_message = "Unknown region \"${var.input.region}\". Supported regions: ${join(", ", sort(keys(local.region_codes)))} (FR-010 / FR-018)."
  }
}

# ─── FR-017 — known service_type at top level ────────────────────────────────
check "service_type_known" {
  assert {
    condition = alltrue([
      for s in var.input.services : contains(keys(local.services), s.type)
    ])
    error_message = "Unknown service_type(s): ${join(", ", [for s in var.input.services : s.type if !contains(keys(local.services), s.type)])}. Supported service types: ${join(", ", sort(keys(local.services)))} (FR-017)."
  }
}

# ─── FR-026 — child-only service used at top level ───────────────────────────
check "child_only_not_at_top_level" {
  assert {
    condition = alltrue([
      for s in var.input.services : !contains(keys(local.child_types), s.type)
    ])
    error_message = "service_type(s) ${join(", ", [for s in var.input.services : "\"${s.type}\"" if contains(keys(local.child_types), s.type)])} are child-only and MUST NOT appear at the top level of services[] (FR-026). Move them under their parent's typed child list (e.g. subnets:, nsg_rules:, private_endpoints:)."
  }
}

# ─── FR-027 — child appears under a permitted parent type ────────────────────
check "child_parent_allowed" {
  assert {
    condition = alltrue(flatten([
      for s in var.input.services : [
        for child_type, ct in local.child_types : (
          length(lookup(s, ct.child_list_key, [])) == 0
          || contains(ct.parent_allowlist, s.type)
        )
      ]
    ]))
    error_message = "One or more child lists were attached to an unsupported parent service_type. Check the FR-027 allowlist (subnets→vnet only; nsg_rules→nsg only; routes→route_table only; private_endpoints→PE-hostable types; diagnostic_settings→diagnostics-capable types)."
  }
}

# ─── FR-033 — topology_scope check ───────────────────────────────────────────
check "topology_scope" {
  assert {
    condition = alltrue([
      for s in var.input.services : (
        contains(keys(local.services), s.type)
        ? (
          local.services[s.type].topology_scope == "either"
          || (local.services[s.type].topology_scope == "hub-only" && var.input.topology == "hub")
          || (local.services[s.type].topology_scope == "spoke-only" && var.input.topology == "spoke")
          || (local.services[s.type].topology_scope == "prd-hub-only" && var.input.topology == "hub" && var.input.environment == "prd")
        )
        : true
      )
    ])
    error_message = join(" ", [
      for s in var.input.services : "service_type \"${s.type}\" has topology_scope=\"${local.services[s.type].topology_scope}\" but request is (topology=\"${var.input.topology}\", environment=\"${var.input.environment}\")."
      if contains(keys(local.services), s.type)
      && !(
        local.services[s.type].topology_scope == "either"
        || (local.services[s.type].topology_scope == "hub-only" && var.input.topology == "hub")
        || (local.services[s.type].topology_scope == "spoke-only" && var.input.topology == "spoke")
        || (local.services[s.type].topology_scope == "prd-hub-only" && var.input.topology == "hub" && var.input.environment == "prd")
      )
    ])
  }
}

# ─── FR-029 — duplicate purpose per (parent, child_type) ─────────────────────
check "purpose_unique_per_parent" {
  assert {
    condition = alltrue(flatten([
      for s_idx, s in var.input.services : [
        for child_type, ct in local.child_types : (
          ct.numbering != "purpose-keyed"
          ? true
          : length([for c in lookup(s, ct.child_list_key, []) : c.purpose])
          == length(distinct([for c in lookup(s, ct.child_list_key, []) : c.purpose]))
        )
      ]
    ]))
    error_message = "Duplicate purpose token(s) detected within a (parent, child_type) group. Each purpose-keyed child (subnet, nsg_rule, route) MUST carry a unique purpose token under its parent (FR-029)."
  }
}

# ─── FR-032 — unresolved private_endpoint.subnet reference ───────────────────
check "pe_subnet_resolves" {
  assert {
    condition = alltrue([
      for r in local.parsed : (
        r.type != "private_endpoint" || r.pe_subnet == null
        ? true
        : contains([for x in local.named : x.canonical_name if x.type == "subnet"], r.pe_subnet)
      )
    ])
    error_message = "private_endpoint(s) reference subnet canonical names not present in this batch: ${join(", ", distinct([for r in local.parsed : r.pe_subnet if r.type == "private_endpoint" && r.pe_subnet != null && !contains([for x in local.named : x.canonical_name if x.type == "subnet"], r.pe_subnet)]))}. Declare the subnet under its parent vnet in the same input (FR-032)."
  }
}

# ─── FR-016 — per-service length budget ──────────────────────────────────────
check "length_budget" {
  assert {
    condition = alltrue([
      for r in local.named : (
        r.is_child
        ? length(r.canonical_name) <= lookup(local.services, r.parent_type, { max_length = 80 }).max_length
        : length(r.canonical_name) <= local.services[r.type].max_length
      )
      if contains(keys(local.services), r.type) || r.is_child
    ])
    error_message = join(" | ", [
      for r in local.named : "service_type \"${r.type}\" candidate \"${r.canonical_name}\" exceeds max_length ${r.is_child ? lookup(local.services, r.parent_type, { max_length = 80 }).max_length : local.services[r.type].max_length} (over by ${length(r.canonical_name) - (r.is_child ? lookup(local.services, r.parent_type, { max_length = 80 }).max_length : local.services[r.type].max_length)} bytes). Remediate by allocating a shorter region short code or by allocating the resource to a different tenant. Truncation and hashing are forbidden (FR-016 / FR-022)."
      if(contains(keys(local.services), r.type) || r.is_child)
      && length(r.canonical_name) > (r.is_child ? lookup(local.services, r.parent_type, { max_length = 80 }).max_length : local.services[r.type].max_length)
    ])
  }
}

# ─── FR-016 — canonical shape regex ──────────────────────────────────────────
check "shape_regex" {
  assert {
    condition = alltrue([
      for r in local.named : (
        r.is_child && lookup(local.child_types, r.type, { numbering = "" }).numbering == "purpose-keyed"
        ? can(regex("^[a-z]{2,8}-[a-z0-9-]{2,16}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{1,4}-[a-z0-9]{2,5}-[0-9]{3}$", r.canonical_name))
        : r.is_child
        ? (
          r.shape == "hyphenated"
          ? can(regex("^[a-z]{2,8}-[a-z0-9-]+-[0-9]{3}$", r.canonical_name))
          : can(regex("^[a-z0-9]+$", r.canonical_name))
        )
        : (
          r.shape == "hyphenated"
          ? can(regex("^[a-z]{2,8}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{1,4}-[a-z0-9]{2,5}-[0-9]{3}$", r.canonical_name))
          : can(regex("^[a-z]{2,8}(hub|sp[0-9]{2})[a-z0-9]{1,4}[a-z0-9]{2,5}[0-9]{3}$", r.canonical_name))
        )
      )
    ])
    error_message = "Candidate name failed its canonical-shape regex. Offenders: ${join(", ", [for r in local.named : "(${r.shape}/${r.is_child ? "child" : "top"}/${r.type}) \"${r.canonical_name}\""
      if !(
        r.is_child && lookup(local.child_types, r.type, { numbering = "" }).numbering == "purpose-keyed"
        ? can(regex("^[a-z]{2,8}-[a-z0-9-]{2,16}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{1,4}-[a-z0-9]{2,5}-[0-9]{3}$", r.canonical_name))
        : r.is_child
        ? (
          r.shape == "hyphenated"
          ? can(regex("^[a-z]{2,8}-[a-z0-9-]+-[0-9]{3}$", r.canonical_name))
          : can(regex("^[a-z0-9]+$", r.canonical_name))
        )
        : (
          r.shape == "hyphenated"
          ? can(regex("^[a-z]{2,8}-(hub|sp(0[1-9]|[1-9][0-9]))-[a-z0-9]{1,4}-[a-z0-9]{2,5}-[0-9]{3}$", r.canonical_name))
          : can(regex("^[a-z]{2,8}(hub|sp[0-9]{2})[a-z0-9]{1,4}[a-z0-9]{2,5}[0-9]{3}$", r.canonical_name))
        )
      )
    ])}. (FR-016)."
  }
}

# ─── FR-039 — unmatched override key ─────────────────────────────────────────
check "overrides_match_emitted" {
  assert {
    condition = alltrue([
      for k in keys(var.input.overrides) : contains([for r in local.named_with_rg : r.canonical_name], k)
    ])
    error_message = "overrides keys do not match any emitted canonical name: ${join(", ", [for k in keys(var.input.overrides) : k if !contains([for r in local.named_with_rg : r.canonical_name], k)])} (FR-039)."
  }
}

# ─── FR-008 — instance cap (999) ─────────────────────────────────────────────
check "instance_cap" {
  assert {
    condition = alltrue([
      for r in local.numbered : (r.instance == null || r.instance <= 999)
    ])
    error_message = "Instance count exceeded 999 cap. Offending group(s): ${join(", ", distinct([for r in local.numbered : "(type=${r.type}, parent_ref=${r.parent_ref == null ? "<top-level>" : tostring(r.parent_ref)})" if r.instance != null && r.instance > 999]))} (FR-008)."
  }
}

# ─── FR-030 — purpose-keyed child of hyphen-forbidden parent ────────────────
check "no_purpose_keyed_under_concatenated_parent" {
  assert {
    condition = alltrue([
      for r in local.parsed : (
        r.is_child
        && r.purpose != null
        && lookup(local.services, r.parent_type, { shape = "hyphenated" }).shape == "concatenated"
      ) ? false : true
    ])
    error_message = "Purpose-keyed children of hyphen-forbidden parents are not permitted on day-one (FR-030). Offending: ${join(", ", [for r in local.parsed : "(child_type=${r.type}, parent_service_type=${r.parent_type})" if r.is_child && r.purpose != null && lookup(local.services, r.parent_type, { shape = "hyphenated" }).shape == "concatenated"])}."
  }
}

# ─── FR-015 — override tag key validation ────────────────────────────────────
check "override_tag_keys_valid" {
  assert {
    condition = alltrue(flatten([
      for canon, ov in var.input.overrides : [
        for k in keys(try(tomap(lookup(ov, "tags", {})), {})) : (
          length(k) >= 1
          && length(k) <= 512
          && !contains(["microsoft", "azure", "windows"], lower(substr(k, 0, length(k) < 9 ? length(k) : 9)))
          && !startswith(lower(k), "microsoft")
          && !startswith(lower(k), "azure")
          && !startswith(lower(k), "windows")
        )
      ]
    ]))
    error_message = "Override tag key(s) violate Azure tag-key rules (length 1..512, no reserved prefix microsoft/azure/windows). Offenders: ${join(", ", flatten([for canon, ov in var.input.overrides : [for k in keys(try(tomap(lookup(ov, "tags", {})), {})) : "(${canon}: ${k})" if !(length(k) >= 1 && length(k) <= 512 && !startswith(lower(k), "microsoft") && !startswith(lower(k), "azure") && !startswith(lower(k), "windows"))]]))} (FR-015)."
  }
}

# ─── FR-026 — catalogue completeness: services ↔ defaults parity ──────────────
check "catalogue_completeness_defaults" {
  assert {
    condition = (
      length(setsubtract(keys(local.services), keys(local.defaults))) == 0
      && length(setsubtract(keys(local.defaults), keys(local.services))) == 0
    )
    error_message = "Catalogue mismatch: local.services keys missing from local.defaults: ${jsonencode(setsubtract(keys(local.services), keys(local.defaults)))}; local.defaults keys missing from local.services: ${jsonencode(setsubtract(keys(local.defaults), keys(local.services)))} (FR-012)."
  }
}

# ─── FR-010 — region short-code uniqueness ───────────────────────────────────
check "region_code_uniqueness" {
  assert {
    condition     = length(values(local.region_codes)) == length(distinct(values(local.region_codes)))
    error_message = "local.region_codes contains duplicate short codes: ${jsonencode([for code in values(local.region_codes) : code if length([for c in values(local.region_codes) : c if c == code]) > 1])} (FR-010)."
  }
}

# ─── FR-027 — child catalogue parent_allowlist references known services ────
check "child_parent_allowlist_known" {
  assert {
    condition = alltrue(flatten([
      for child_type, ct in local.child_types : [
        for p in ct.parent_allowlist : contains(keys(local.services), p)
      ]
    ]))
    error_message = "local.child_types.parent_allowlist references unknown service_type(s) (FR-027)."
  }
}
