data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.apim.vnet.subnet
  virtual_network_name = var.services.apim.vnet.name
  resource_group_name  = var.services.apim.vnet.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}