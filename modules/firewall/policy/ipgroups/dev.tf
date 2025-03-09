variable "source_ip_groups" {}
variable "source_function_app_ip_groups" {}
variable "source_logic_app_ip_groups" {}
  
}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = var.vnet.subscription_id
}

data "azurerm_firewall_policy" "this" {
  provider            = azurerm.vnet
  name                = var.vnet.firewall.policy.name
  resource_group_name = var.vnet.resource_group_name
}

resource "azurerm_ip_group" "this" {
  name                = "development-ipgroup"
  location            = var.vnet.firewall.location
  resource_group_name = var.vnet.firewall.resource_group_name

  cidrs = source_ip_groups

  tags = {
    environment = "Development"
  }
}

resource "azurerm_ip_group" "functionapp" {
  name                = "development-function-app-ipgroup"
  location            = var.vnet.firewall.location
  resource_group_name = var.vnet.firewall.resource_group_name

  cidrs = source_function_app_ip_groups

  tags = {
    environment = "Development"
  }
}

resource "azurerm_ip_group" "logicapp" {
  name                = "development-logic-app-ipgroup"
  location            = var.vnet.firewall.location
  resource_group_name = var.vnet.firewall.resource_group_name

  cidrs = source_logic_app_ip_groups

  tags = {
    environment = "Development"
  }
}
