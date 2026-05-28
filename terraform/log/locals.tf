###############################################################################
# terraform/log/locals.tf
###############################################################################

locals {
  allowed_regions = ["swedencentral"]

  # Engine doesn't publicly expose region_codes; root pins it.
  region_codes = {
    swedencentral = "sdc"
  }

  input = {
    topology    = var.topology
    tenant      = var.tenant
    environment = var.environment
    region      = var.region
    repo        = var.repo
    services = [
      {
        type  = "log_analytics"
        count = 1
      },
    ]
  }
}
