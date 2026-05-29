# Shape var.* into the single wrapper-module input bundle.
locals {
  dnszones_input = {
    subscription_id         = var.subscription_id
    region                  = var.region
    repo                    = var.repo
    topology                = var.topology
    tenant                  = var.tenant
    environment             = var.environment
    custom_zones            = var.custom_zones
    disable_catalogue_zones = var.disable_catalogue_zones
  }
}
