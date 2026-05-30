locals {
  defaults = {
    application_type  = "web"
    retention_in_days = 90
  }

  config = merge(local.defaults, var.overrides)
}
