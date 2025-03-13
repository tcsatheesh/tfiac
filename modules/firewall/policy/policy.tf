variable "log" {}
variable "vnet" {}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = var.vnet.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = var.log.subscription_id
}

module "firewall_policy" {
  source              = "Azure/avm-res-network-firewallpolicy/azurerm"
  name                = var.vnet.firewall.policy.name
  location            = var.vnet.firewall.location
  resource_group_name = var.vnet.firewall.resource_group_name
}