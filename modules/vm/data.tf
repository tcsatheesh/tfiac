data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.buildsvr.vnet.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}
