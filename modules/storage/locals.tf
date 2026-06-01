locals {
  defaults = {
    account_tier             = "Standard"
    account_replication_type = "LRS"
    min_tls_version          = "TLS1_2"
  }

  config = merge(local.defaults, var.overrides)

  # C-035 (FR-034) — private endpoint name. `pep-${canonical_name}` is <= 80
  # chars (storage account names are <= 24), well within the PE name limit.
  pe_name = "pep-${var.canonical_name}"
}
