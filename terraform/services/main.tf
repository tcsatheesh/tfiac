module "keyvault" {
  source     = "../../modules/keyvault"
  count      = local.services.key_vault != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "appinsights" {
  source     = "../../modules/appinsights"
  count      = local.services.app_insights != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "landing_zone" {
  source               = "../../modules/storage"
  count                = local.services.landing != null ? 1 : 0
  dns                  = local.dns
  log                  = local.log
  vnet                 = local.vnet
  services             = local.services
  storage_account_name = local.services.landing.storage_account_name
  depends_on           = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "aiservices" {
  source     = "../../modules/aiservices"
  count      = local.services.ai_services != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "aifoundry" {
  source                = "../../modules/aifoundry"
  count                 = local.services.ai_foundry != null ? 1 : 0
  dns                   = local.dns
  log                   = local.log
  vnet                  = local.vnet
  services              = local.services
  app_insights_id       = module.appinsights[0].app_insights_id
  keyvault_id           = module.keyvault[0].keyvault_id
  container_registry_id = module.cntreg[0].container_registry_id
  ai_services_id        = module.aiservices[0].ai_services_id
  depends_on            = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "openai" {
  source     = "../../modules/openai"
  count      = local.services.open_ai != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "docint" {
  source     = "../../modules/docint"
  count      = local.services.document_intelligence != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "language" {
  source     = "../../modules/language"
  count      = local.services.ai_language != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "cntreg" {
  source     = "../../modules/cntreg"
  count      = local.services.container_registry != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "uai" {
  source     = "../../modules/uai"
  count      = local.services.uai != null ? 1 : 0
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "aml" {
  source                = "../../modules/aml"
  count                 = local.services.aml != null ? 1 : 0
  dns                   = local.dns
  log                   = local.log
  vnet                  = local.vnet
  services              = local.services
  app_insights_id       = module.appinsights[0].app_insights_id
  keyvault_id           = module.keyvault[0].keyvault_id
  container_registry_id = module.cntreg[0].container_registry_id
  uai_id                = module.uai[0].uai_id
  depends_on            = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "ai_search" {
  source             = "../../modules/search"
  count              = local.services.ai_search != null ? 1 : 0
  dns                = local.dns
  log                = local.log
  vnet               = local.vnet
  services           = local.services
  storage_account_id = module.landing_zone[0].storage_account_id
  open_ai_id         = module.openai[0].open_ai_id

  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "function_app" {
  source                           = "../../modules/fnapp"
  count                            = local.services.function_app != null ? 1 : 0
  dns                              = local.dns
  log                              = local.log
  vnet                             = local.vnet
  services                         = local.services
  app_insights_instrumentation_key = module.appinsights[0].instrumentation_key
  app_insights_connection_string   = module.appinsights[0].connection_string
  depends_on                       = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "logic_app" {
  source                           = "../../modules/lgapp"
  count                            = local.services.logic_app != null ? 1 : 0
  dns                              = local.dns
  log                              = local.log
  vnet                             = local.vnet
  services                         = local.services
  app_insights_instrumentation_key = module.appinsights[0].instrumentation_key
  app_insights_connection_string   = module.appinsights[0].connection_string
  depends_on                       = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "apimananagement" {
  source                          = "../../modules/apim"
  count                           = local.services.apim.deploy_apim ? 1 : 0
  dns                             = local.dns
  log                             = local.log
  vnet                            = local.vnet
  services                        = local.services
  appinsights_instrumentation_key = module.appinsights[0].instrumentation_key
  depends_on                      = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "apimanagementapi" {
  source                          = "../../modules/apim/api"
  count                           = local.services.apim.apis != null ? 1 : 0
  dns                             = local.dns
  log                             = local.log
  vnet                            = local.vnet
  services                        = local.services
  appinsights_instrumentation_key = module.appinsights[0].instrumentation_key
  depends_on                      = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
    azurerm.apim     = azurerm.apim
  }
}