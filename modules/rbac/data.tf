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
