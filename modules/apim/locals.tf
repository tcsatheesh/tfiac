locals {
  defaults = {
    publisher_name  = "tfiac"
    publisher_email = "tfiac@example.com"
    sku_name        = "Developer_1"
  }

  config = merge(local.defaults, var.overrides)
}
