locals {
  defaults = {}
  config   = merge(local.defaults, var.overrides)
}
