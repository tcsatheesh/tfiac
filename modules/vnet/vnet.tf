variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "firewall" {}
variable "remote_vnet" {}

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
provider "azurerm" {
  features {}
  alias           = "remote_vnet"
  subscription_id = var.remote_vnet.subscription_id
}
provider "azurerm" {
  features {}
  alias           = "dns"
  subscription_id = var.dns.subscription_id
}

data "azurerm_private_dns_zone" "this" {
  for_each            = tomap(var.dns.domain_names)
  provider            = azurerm.dns
  name                = each.value
  resource_group_name = var.dns.resource_group_name
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
    name                   = "firewall-appliance"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall.ip
  }
}

module "nsg" {
  for_each            = tomap(var.vnet.subnets)
  source              = "Azure/avm-res-network-networksecuritygroup/azurerm"
  resource_group_name = azurerm_resource_group.this.name
  name                = each.value.nsg
  location            = var.vnet.location

  security_rules = each.value.nsg_rules
}


# Creating a virtual network with a unique name, telemetry settings, and in the specified resource group and location.
module "vnet" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  name                = var.vnet.name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.vnet.location

  address_space = var.vnet.address_space

  diagnostic_settings = {
    sendToLogAnalytics = {
      name                           = "sendToLogAnalytics"
      workspace_resource_id          = data.azurerm_log_analytics_workspace.this.id
      log_analytics_destination_type = "Dedicated"
    }
  }
}

module "subnets" {
  for_each = tomap(var.vnet.subnets)
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  virtual_network = {
    resource_id = module.vnet.resource_id
  }
  name             = each.key
  address_prefixes = each.value.address_prefixes
  network_security_group = each.value.add_nsg ? {
    id = module.nsg[each.key].resource_id
  } : null

  route_table = each.value.add_route_table ? {
    id = azurerm_route_table.this.id
  } : null

  service_endpoints = each.value.service_endpoints
}

data "azurerm_virtual_network" "remote" {
  provider            = azurerm.remote_vnet
  name                = var.remote_vnet.name
  resource_group_name = var.remote_vnet.resource_group_name
}

locals {
  peering_enabled = var.remote_vnet.name != var.vnet.name
}

module "peering" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  for_each = local.peering_enabled ? { "enabled" = true } : {}
  virtual_network = {
    resource_id = module.vnet.resource_id
  }
  remote_virtual_network = {
    resource_id = data.azurerm_virtual_network.remote.id
  }
  name                                 = "${var.vnet.name}-local-to-${var.remote_vnet.name}-remote"
  allow_forwarded_traffic              = true
  allow_gateway_transit                = true
  allow_virtual_network_access         = true
  use_remote_gateways                  = false
  create_reverse_peering               = true
  reverse_name                         = "${var.remote_vnet.name}-remote-to-${var.vnet.name}-local"
  reverse_allow_forwarded_traffic      = false
  reverse_allow_gateway_transit        = false
  reverse_allow_virtual_network_access = true
  reverse_use_remote_gateways          = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each  = tomap(var.dns.domain_names)
  name                  = var.vnet.name
  resource_group_name   = var.dns.resource_group_name
  private_dns_zone_name = each.value
  virtual_network_id    = module.vnet.resource_id
  registration_enabled  = false
}

