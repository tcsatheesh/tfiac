module "this" {
  source              = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  location            = var.services.location
  enable_telemetry    = false
  name                = var.services.uai.name
  resource_group_name = var.services.resource_group_name
}