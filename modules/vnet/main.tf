resource "azurerm_resource_group" "this" {
  name     = var.vnet.resource_group_name
  location = var.vnet.location
}

resource "azurerm_route_table" "this" {
  location            = var.vnet.location
  name                = var.vnet.route_table_name
  resource_group_name = azurerm_resource_group.this.name

  route {
    name                   = "route-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall.ip
  }
}

module "nsgrules" {
  source = "./nsgrules"
}

module "nsg" {
  for_each            = tomap(var.vnet.subnets)
  source              = "Azure/avm-res-network-networksecuritygroup/azurerm"
  resource_group_name = azurerm_resource_group.this.name
  name                = each.value.nsg
  location            = var.vnet.location

  security_rules   = each.value.has_nsg_rules ? module.nsgrules.nsg_rules["${each.key}"] : null
  enable_telemetry = false
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
  enable_telemetry = false
}

module "subnets" {
  for_each = tomap(var.vnet.subnets)
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  virtual_network = {
    resource_id = module.vnet.resource_id
  }
  name           = each.value.name
  address_prefix = each.value.address_prefix
  network_security_group = each.value.add_nsg ? {
    id = module.nsg[each.key].resource_id
  } : null

  route_table = each.value.add_route_table ? {
    id = azurerm_route_table.this.id
  } : null

  service_endpoints               = each.value.service_endpoints
  delegation                      = each.value.delegation
  default_outbound_access_enabled = true
}

module "peering" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  count  = local.peering_enabled ? 1 : 0
  virtual_network = {
    resource_id = module.vnet.resource_id
  }
  remote_virtual_network = {
    resource_id = data.azurerm_virtual_network.remote[count.index].id
  }
  name                                 = var.vnet.vnet_peering.local_name
  allow_forwarded_traffic              = true
  allow_gateway_transit                = false
  allow_virtual_network_access         = true
  use_remote_gateways                  = false
  create_reverse_peering               = true
  reverse_name                         = var.vnet.vnet_peering.remote_name
  reverse_allow_forwarded_traffic      = false
  reverse_allow_gateway_transit        = false
  reverse_allow_virtual_network_access = true
  reverse_use_remote_gateways          = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = tomap(var.dns.domain_names)
  name                  = var.vnet.name
  resource_group_name   = var.dns.resource_group_name
  private_dns_zone_name = each.value
  virtual_network_id    = module.vnet.resource_id
  registration_enabled  = false
}

module "firewall" {
  source                        = "./firewall"
  count                         = local.firewall_enabled ? 1 : 0
  dns                           = var.dns
  log                           = var.log
  vnet                          = var.vnet
  firewall                      = var.firewall
  remote_vnet                   = var.remote_vnet
  firewall_subnet_id            = module.subnets["firewall"].resource_id
  firewall_management_subnet_id = module.subnets["firewall-mgmt"].resource_id
  providers = {
    azurerm.vnet        = azurerm.vnet
    azurerm.log         = azurerm.log
    azurerm.dns         = azurerm.dns
    azurerm.remote_vnet = azurerm.remote_vnet
  }
}

module "bastion" {
  source            = "./bastion"
  count             = var.vnet.bastion != null ? 1 : 0
  vnet              = var.vnet
  bastion_subnet_id = module.subnets["bastion"].resource_id
  providers = {
    azurerm.vnet = azurerm.vnet
  }
}
