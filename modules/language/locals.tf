locals {
  defaults = {
    sku_name = "S"
  }

  config = merge(local.defaults, var.overrides)
}
