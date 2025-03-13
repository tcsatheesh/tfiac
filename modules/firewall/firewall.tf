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

data "azurerm_subnet" "firewall" {
  provider             = azurerm.vnet
  name                 = var.vnet.firewall.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_subnet" "firewallmanagement" {
  provider             = azurerm.vnet
  name                 = var.vnet.firewall.management.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "fw_public_ip" {
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  version             = "0.1.0"
  name                = "pip-fw-${var.vnet.firewall.public_ip_name}"
  location            = var.vnet.firewall.location
  resource_group_name = var.vnet.firewall.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# module "fw_public_management_ip" {
#   source  = "Azure/avm-res-network-publicipaddress/azurerm"
#   version = "0.1.0"
#   name                = "pip-fw-${var.vnet.firewall.management.public_ip_name}"
#   location            = var.vnet.firewall.management.location
#   resource_group_name = var.vnet.firewall.management.resource_group_name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

module "firewall" {
  source              = "Azure/avm-res-network-firewall/azurerm"
  name                = var.vnet.firewall.name
  location            = var.vnet.firewall.location
  resource_group_name = var.vnet.firewall.resource_group_name
  firewall_sku_tier   = "Standard"
  firewall_sku_name   = "AZFW_VNet"
  firewall_zones      = ["1", "2", "3"]
  firewall_policy_id  = module.fwpolicy.resource.id
  firewall_ip_configuration = [
    {
      name                 = "ipconfig-${var.vnet.firewall.name}"
      subnet_id            = data.azurerm_subnet.subnet.id
      public_ip_address_id = module.fw_public_ip.public_ip_id
    }
  ]
  diagnostic_settings = {
    to_law = {
      name                  = "tola-${var.vnet.firewall.name}"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_groups            = ["allLogs"]
      metric_categories     = ["AllMetrics"]
    }
  }
}
