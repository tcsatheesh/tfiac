module "aml_storage" {
  source               = "../../modules/storage"
  dns                  = var.dns
  log                  = var.log
  vnet                 = var.vnet
  services             = var.services
  storage_account_name = var.services.aml.storage_account_name
  providers = {
    azurerm.services = azurerm.services
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "azureml" {
  source              = "Azure/avm-res-machinelearningservices-workspace/azurerm"
  location            = var.services.location
  name                = var.services.aml.name
  resource_group_name = var.services.resource_group_name

  storage_account = {
    resource_id = module.aml_storage.storage_account_id
    create_new  = false
  }

  key_vault = {
    resource_id = var.keyvault_id
    create_new  = false
  }

  container_registry = {
    resource_id = var.container_registry_id
    create_new  = false
  }

  application_insights = {
    resource_id = var.app_insights_id
    create_new  = false
  }
  enable_telemetry = false

  private_endpoints = {
    api = {
      name                          = "pe-api-aml"
      subnet_resource_id            = data.azurerm_subnet.this.id
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.amlapi.id]
      inherit_lock                  = false
      resource_group_name = var.vnet.resource_group_name
    }
    notebooks = {
      name                          = "pe-notebooks-aml"
      subnet_resource_id            = data.azurerm_subnet.this.id
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.amlnotebook.id]
      inherit_lock                  = false
      resource_group_name = var.vnet.resource_group_name
    }
  }
}

