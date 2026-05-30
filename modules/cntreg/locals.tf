locals {
  defaults = {
    sku           = "Standard"
    admin_enabled = false
  }

  config = merge(local.defaults, var.overrides)
}
