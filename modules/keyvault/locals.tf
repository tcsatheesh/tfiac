locals {
  defaults = {
    sku_name                   = "standard"
    purge_protection_enabled   = true
    soft_delete_retention_days = 90
    rbac_authorization_enabled = true
  }

  config = merge(local.defaults, var.overrides)
}
