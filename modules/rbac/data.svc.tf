data "azurerm_virtual_network" "this" {
  provider            = azurerm.vnet
  name                = var.vnet.name
  resource_group_name = var.vnet.resource_group_name
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.vnet.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["cognitiveservices"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

data "azurerm_container_registry" "acr" {
  name                = var.services.container_registry.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_linux_function_app" "fnapp" {
  count               = var.services.function_app != null ? 1 : 0
  name                = var.services.function_app.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_storage_account" "landing" {
  count               = var.services.landing != null ? 1 : 0
  name                = var.services.landing.storage_account_name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_storage_account" "aml_storage" {
  count               = var.services.aml != null ? 1 : 0
  name                = var.services.aml.storage_account_name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_storage_account" "function_app_storage" {
  count               = var.services.function_app != null ? 1 : 0
  name                = var.services.function_app.storage_account_name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_storage_account" "logic_app_storage" {
  count               = var.services.logic_app != null ? 1 : 0
  name                = var.services.logic_app.storage_account_name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_storage_account" "ai_services_storage" {
  count               = var.services.ai_services != null ? 1 : 0
  name                = var.services.ai_services.storage_account_name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_storage_account" "ai_foundry_storage" {
  count               = var.services.ai_foundry != null ? 1 : 0
  name                = var.services.ai_foundry.storage_account_name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_key_vault" "key_vault" {
  name                = var.services.key_vault.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_application_insights" "app_insights" {
  name                = var.services.app_insights.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_resource_group" "rg" {
  name     = var.services.resource_group_name
  provider = azurerm.services
}

data "azurerm_cognitive_account" "open_ai" {
  name                = var.services.open_ai.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_resources" "azureml" {
  count               = var.services.aml != null ? 1 : 0
  type                = "Microsoft.MachineLearningServices/workspaces"
  name                = var.services.aml.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_resources" "ai_foundry" {
  count               = var.services.ai_foundry != null ? 1 : 0
  type                = "Microsoft.MachineLearningServices/workspaces"
  name                = var.services.ai_foundry.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_resources" "ai_services" {
  count               = var.services.ai_services != null ? 1 : 0
  type                = "Microsoft.CognitiveServices/accounts"
  name                = var.services.ai_services.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_cognitive_account" "ai_language" {
  count               = var.services.ai_language != null ? 1 : 0
  name                = var.services.ai_language.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_cognitive_account" "docint" {
  count               = var.services.document_intelligence != null ? 1 : 0
  name                = var.services.document_intelligence.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}

data "azurerm_search_service" "ai_search" {
  count               = var.services.ai_search != null ? 1 : 0
  name                = var.services.ai_search.name
  resource_group_name = var.services.resource_group_name
  provider            = azurerm.services
}
