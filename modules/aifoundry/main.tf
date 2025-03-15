module "ai_foundry_storage" {
  source               = "../../modules/storage"
  dns                  = var.dns
  log                  = var.log
  vnet                 = var.vnet
  services             = var.services
  storage_account_name = var.services.ai_foundry.storage_account_name
  providers = {
    azurerm.services = azurerm.services
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

resource "azurerm_ai_foundry" "this" {
  name                    = var.services.ai_foundry.name
  location                = var.services.ai_services.location
  resource_group_name     = var.services.resource_group_name
  storage_account_id      = module.ai_foundry_storage.storage_account_id
  key_vault_id            = var.keyvault_id
  application_insights_id = var.app_insights_id
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_ai_foundry_project" "this" {
  for_each                     = tomap(var.services.ai_foundry.projects)
  name                         = each.value.name
  location                     = each.value.location
  description                  = each.value.description
  friendly_name                = each.value.friendly_name
  ai_services_hub_id           = azurerm_ai_foundry.this.id
  high_business_impact_enabled = true
  identity {
    type = "SystemAssigned"
  }
}