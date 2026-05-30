locals {
  defaults = {
    kind     = "Hub"
    sku_name = "Basic"
  }

  config = merge(local.defaults, var.overrides)
}
