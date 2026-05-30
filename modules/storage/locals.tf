locals {
  defaults = {
    account_tier             = "Standard"
    account_replication_type = "LRS"
    min_tls_version          = "TLS1_2"
  }

  config = merge(local.defaults, var.overrides)
}
