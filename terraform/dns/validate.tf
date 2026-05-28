###############################################################################
# terraform/dns/validate.tf  (feature 002)
#
# Hard-halt validators for catalogue-aware rules. We use root-level
# `terraform_data` resources with `lifecycle.precondition` blocks because:
#   - variable.validation in the module cannot reach module-local data
#     (`local.catalogue`)
#   - Terraform 1.9 forbids `expect_failures` from referencing resources
#     scoped inside a child module, so the precondition must live in root
#   - `check {}` blocks emit warnings only — not strong enough for FR-017/018
#
# Catalogue data still lives in the module (single source of truth); root
# consumes `module.dnszones.catalogue_keys` and `catalogue_fqdns` outputs.
###############################################################################

# ─── FR-029 — subscription pinning (check-block; warning in plan, error in test)
check "subscription_pinned" {
  assert {
    condition = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = format(
      "subscription_id mismatch: var.subscription_id=%q but provider is authenticated against %q. Refusing to plan the prd-hub DNS stack against the wrong subscription (FR-029).",
      var.subscription_id,
      data.azurerm_client_config.current.subscription_id,
    )
  }
}

# ─── FR-018 — disable_catalogue_zones membership (hard halt) ───────────────
resource "terraform_data" "guard_disable_keys_known" {
  lifecycle {
    precondition {
      condition = length(setsubtract(
        toset(var.disable_catalogue_zones),
        toset(module.dnszones.catalogue_keys),
      )) == 0
      error_message = format(
        "disable_catalogue_zones contains unknown key(s) %v. Valid catalogue keys: %v (FR-018).",
        sort(tolist(setsubtract(toset(var.disable_catalogue_zones), toset(module.dnszones.catalogue_keys)))),
        module.dnszones.catalogue_keys,
      )
    }
  }
}

# ─── FR-017 — custom_zones shadowing (hard halt) ─────────────────────────
resource "terraform_data" "guard_custom_zones_no_shadow" {
  lifecycle {
    precondition {
      condition = length(setintersection(
        toset(var.custom_zones),
        toset(module.dnszones.catalogue_fqdns),
      )) == 0
      error_message = format(
        "custom_zones entries shadow catalogue FQDN(s) %v. Use disable_catalogue_zones to opt out of a catalogue key instead. Protected catalogue FQDNs: %v (FR-017).",
        sort(tolist(setintersection(toset(var.custom_zones), toset(module.dnszones.catalogue_fqdns)))),
        module.dnszones.catalogue_fqdns,
      )
    }
  }
}
