###############################################################################
# terraform/log/main.tf
###############################################################################

module "naming" {
  source = "../../modules/naming"
  input  = local.input
}

data "azurerm_client_config" "current" {}

module "log" {
  source = "../../modules/loganalytics"

  naming            = module.naming.names
  region            = var.region
  region_code       = local.region_codes[var.region]
  input             = local.input
  retention_in_days = var.retention_in_days
  sku               = var.sku
}
