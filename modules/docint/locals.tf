locals {
  defaults = {
    sku_name = "S0"
  }

  config = merge(local.defaults, var.overrides)
}
