data "azurerm_client_config" "this" {}

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
  name                = var.dns.domain_names["containerregistry"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_private_dns_zone" "amlapi" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["amlapi"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_private_dns_zone" "amlnotebook" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["amlnotebook"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}