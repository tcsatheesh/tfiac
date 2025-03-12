variable "dns" {}
variable "log" {}
variable "vnet" {}
variable firewall {}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.vnet.subscription_id
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

resource "azurerm_resource_group" "this" {
  name     = var.vnet.resource_group_name
  location = var.vnet.location
}

resource "azurerm_route_table" "this" {
  location            = var.vnet.location
  name                = var.vnet.route_table_name
  resource_group_name = azurerm_resource_group.this.name

  route {
    name           = "firewall-appliance"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall.ip
  }
}

resource "azurerm_network_security_group" "subnet" {
  for_each = tomap(var.vnet.subnets)

  location            = var.vnet.location
  name                = each.value.nsg
  resource_group_name = azurerm_resource_group.this.name
}


# Creating a virtual network with a unique name, telemetry settings, and in the specified resource group and location.
module "vnet" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  name                = var.vnet.name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.vnet.location

  address_space = var.vnet.address_space

  for_each = tomap(var.vnet.subnets)
  subnets = {
    subnet = {
      name                            = each.key
      default_outbound_access_enabled = false
      address_prefixes                = each.value.address_prefix
      network_security_group = {
        id = azurerm_network_security_group.subnet[each.key].id
      }
      route_table = {
        id = each.value.add_route_table ? azurerm_route_table.this.id : null
      }
      service_endpoints = each.value.service_endpoints
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

