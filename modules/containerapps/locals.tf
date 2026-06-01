locals {
  defaults = {
    workload_profile_name = "Consumption"
    workload_profile_type = "Consumption"
  }

  config = merge(local.defaults, var.overrides)
}
