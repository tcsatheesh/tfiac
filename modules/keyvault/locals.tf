locals {
  defaults = {
    sku_name                   = "standard"
    purge_protection_enabled   = true
    soft_delete_retention_days = 90
    rbac_authorization_enabled = true
  }

  config = merge(local.defaults, var.overrides)

  # C-050 (FR-041) — private endpoint name. `pep-${canonical_name}` is well
  # within the PE name limit (key vault names are <= 24 chars).
  pe_name = "pep-${var.canonical_name}"
}
