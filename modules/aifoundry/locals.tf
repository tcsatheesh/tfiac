locals {
  defaults = {
    public_network_access = "Enabled"
  }

  config = merge(local.defaults, var.overrides)
}
