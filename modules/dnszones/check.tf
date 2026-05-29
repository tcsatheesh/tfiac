# Cross-field invariants enforced via terraform_data preconditions so failures
# surface at plan time (FR-031). Each message names the offending value(s) so
# operators can pinpoint the fix without re-reading the spec (SC-005).

resource "terraform_data" "assertions" {
  triggers_replace = {
    catalogue_keys_hash  = sha1(jsonencode(sort(keys(local.catalogue))))
    catalogue_fqdns_hash = sha1(jsonencode(sort(values(local.catalogue))))
    custom_zones_hash    = sha1(jsonencode(sort(var.custom_zones)))
    disabled_keys_hash   = sha1(jsonencode(sort(var.disable_catalogue_zones)))
  }

  # DNS-INV-1: catalogue keys are unique by construction (HCL map) - assert
  # the count matches expectations so a stray duplicate at edit time fires.
  # FR-012 also bounds each key: lowercase alphanum + hyphen, length 2..16.
  lifecycle {
    precondition {
      condition = alltrue([
        for k in keys(local.catalogue) :
        can(regex("^[a-z][a-z0-9-]{1,15}$", k))
      ])
      error_message = "DNS-INV-1 / FR-012: at least one catalogue key violates ^[a-z][a-z0-9-]{1,15}$. Offending: ${jsonencode([
        for k in keys(local.catalogue) : k if !can(regex("^[a-z][a-z0-9-]{1,15}$", k))
      ])}."
    }

    # DNS-INV-2: catalogue FQDNs are unique.
    precondition {
      condition = length(values(local.catalogue)) == length(distinct(values(local.catalogue)))
      error_message = "DNS-INV-2: catalogue contains duplicate FQDN(s). Offending: ${jsonencode([
        for f in distinct(values(local.catalogue)) : f
        if length([for v in values(local.catalogue) : v if v == f]) > 1
      ])}."
    }

    # DNS-INV-3 / FR-017: a custom_zones entry must not shadow any catalogue FQDN.
    precondition {
      condition = length([
        for f in var.custom_zones : f
        if contains(values(local.catalogue), f)
      ]) == 0
      error_message = "FR-017 / DNS-INV-3: custom_zones entr(ies) shadow catalogue FQDN(s). Shadowed: ${jsonencode([
        for f in var.custom_zones : f if contains(values(local.catalogue), f)
      ])}. Remove from custom_zones (they are already in the catalogue) or rename them."
    }

    # DNS-INV-5 / FR-018: disable_catalogue_zones must be a subset of catalogue keys.
    precondition {
      condition = length([
        for k in var.disable_catalogue_zones : k
        if !contains(keys(local.catalogue), k)
      ]) == 0
      error_message = "FR-018 / DNS-INV-5: disable_catalogue_zones contains unknown key(s). Unknown: ${jsonencode([
        for k in var.disable_catalogue_zones : k if !contains(keys(local.catalogue), k)
      ])}. Valid catalogue keys: ${jsonencode(sort(keys(local.catalogue)))}."
    }
  }
}
