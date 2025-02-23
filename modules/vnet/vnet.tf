variable "dns" {}
variable "log" {}
variable "vnet" {}
variable firewall {}
variable "services" {}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = var.log.subscription_id
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

resource "azurerm_route_table" "this" {
  location            = var.vnet.location
  name                = "route-az-grp-firewall"
  resource_group_name = var.vnet.resource_group_name

  route {
    name           = "firewall-appliance"
    address_prefix = var.firewall.ip
    next_hop_type  = "VirtualAppliance "
  }
}

resource "azurerm_network_security_group" "dev_subnet" {
  location            = var.vnet.location
  name                = "nsg-${var.vnet.dev_subnet_name}"
  resource_group_name = var.vent.resource_group_name
}
resource "azurerm_network_security_group" "dev_function_app_subnet" {
  location            = var.vnet.location
  name                = "nsg-${var.vnet.dev_function_app_subnet_name}"
  resource_group_name = var.vent.resource_group_name
}
resource "azurerm_network_security_group" "dev_logic_app_subnet" {
  location            = var.vnet.location
  name                = "nsg-${var.vnet.dev_logic_app_subnet_name}"
  resource_group_name = var.vent.resource_group_name
}
resource "azurerm_network_security_group" "pre_subnet" {
  location            = var.vnet.location
  name                = "nsg-${var.vnet.pre_subnet_name}"
  resource_group_name = var.vent.resource_group_name
}
resource "azurerm_network_security_group" "pre_function_app_subnet" {
  location            = var.vnet.location
  name                = "nsg-${var.vnet.pre_function_app_subnet_name}"
  resource_group_name = var.vent.resource_group_name
}
resource "azurerm_network_security_group" "pre_logic_app_subnet" {
  location            = var.vnet.location
  name                = "nsg-${var.vnet.pre_logic_app_subnet_name}"
  resource_group_name = var.vent.resource_group_name
}


# Creating a virtual network with a unique name, telemetry settings, and in the specified resource group and location.
module "vnet" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  name                = var.vnet.name
  enable_telemetry    = false
  resource_group_name = var.vnet.resource_group_name
  location            = var.vnet.location

  address_space = var.vnet.address_space

  subnets = {
    dev = {
      name                            = var.vnet.dev_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.dev_subnet_address_prefixes
      network_security_group = {
        id = azurerm_network_security_group.dev_subnet.id
      }
      route_table = {
        id = azurerm_route_table.this.id
      }
    }
    devFunctionApp = {
      name                            = var.vnet.dev_function_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.dev_function_app_subnet_address_prefixes
      network_security_group = {
        id = azurerm_network_security_group.dev_function_app_subnet.id
      }
      route_table = {
        id = azurerm_route_table.this.id
      }
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
    devLogicApp = {
      name                            = var.vnet.dev_logic_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.dev_logic_app_subnet_address_prefixes
      network_security_group = {
        id = azurerm_network_security_group.dev_logic_app_subnet.id
      }
      route_table = {
        id = azurerm_route_table.this.id
      }
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
    pre = {
      name                            = var.vnet.pre_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_subnet_address_prefixes
      network_security_group = {
        id = azurerm_network_security_group.pre_subnet.id
      }
      route_table = {
        id = azurerm_route_table.this.id
      }
    }
    preFunctionApp = {
      name                            = var.vnet.pre_function_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_function_app_subnet_address_prefixes
      network_security_group = {
        id = azurerm_network_security_group.pre_function_app_subnet.id
      }
      route_table = {
        id = azurerm_route_table.this.id
      }
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
    preLogicApp = {
      name                            = var.vnet.pre_logic_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_logic_app_subnet_address_prefixes
      network_security_group = {
        id = azurerm_network_security_group.pre_logic_app_subnet.id
      }
      route_table = {
        id = azurerm_route_table.this.id
      }
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
  }
  diagnostic_settings = {
    sendToLogAnalytics = {
      name                           = "sendToLogAnalytics"
      workspace_resource_id          = data.azurerm_log_analytics_workspace.this.id
      log_analytics_destination_type = "Dedicated"
    }
  }
}

