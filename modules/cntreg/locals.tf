locals {
  defaults = {
    sku           = "Standard"
    admin_enabled = false
  }

  config = merge(local.defaults, var.overrides)

  # C-020 (FR-029): Azure Private Link requires the Premium ACR SKU, so when a
  # private endpoint is requested we force Premium regardless of the override.
  effective_sku = var.private_endpoint_enabled ? "Premium" : local.config.sku

  # `private_endpoint` row (abbr `pep`, positional child) stays RESERVED in the
  # engine; the in-module name keeps this amendment self-contained.
  # `pep-${canonical_name}` is <= 80 chars (registry names are <= 50).
  pe_name = "pep-${var.canonical_name}"
}
