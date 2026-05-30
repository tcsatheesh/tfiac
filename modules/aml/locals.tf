locals {
  defaults = {
    sku_name = "Basic"
  }

  config = merge(local.defaults, var.overrides)
}
