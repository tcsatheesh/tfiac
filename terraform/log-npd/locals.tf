###############################################################################
# terraform/log-npd/locals.tf
###############################################################################

locals {
  allowed_regions = ["swedencentral"]

  # Engine doesn't publicly expose region_codes; root pins it.
  region_codes = {
    swedencentral = "sdc"
  }

  input = {
    topology    = "hub"
    tenant      = "hub"
    environment = "npd"
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
