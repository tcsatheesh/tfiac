###############################################################################
# terraform/bootstrap/locals.tf
#
# Build the naming-engine input for the tooling stack. We always use
# topology=hub / tenant=hub because tfstate is a shared platform resource.
###############################################################################

locals {
  input = {
    topology    = "hub"
    tenant      = "hub"
    environment = var.environment
    purpose     = var.purpose
    region      = var.region
    repo        = var.repo

    services = [
      { type = "storage", count = 1 },
    ]
  }
}
