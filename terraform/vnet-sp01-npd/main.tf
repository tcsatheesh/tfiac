module "naming" {
  source = "../../modules/naming"
  input  = local.input
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "hub" {
  count   = var.hub_vnet_id == "" ? 1 : 0
  backend = "local"
  config  = { path = var.hub_remote_state_path }
}

locals {
  hub_vnet_id                 = var.hub_vnet_id != "" ? var.hub_vnet_id : try(data.terraform_remote_state.hub[0].outputs.vnet_id, "")
  hub_firewall_private_ip     = var.hub_firewall_private_ip != "" ? var.hub_firewall_private_ip : try(data.terraform_remote_state.hub[0].outputs.firewall_private_ip, "")
  hub_peered_spoke_vnet_names = length(var.hub_peered_spoke_vnet_names) > 0 ? var.hub_peered_spoke_vnet_names : try(data.terraform_remote_state.hub[0].outputs.peered_spoke_vnet_names, [])
  enable_default_route        = local.hub_firewall_private_ip != ""
  enable_peering              = local.hub_vnet_id != ""
}

module "network" {
  source = "../../modules/network"

  naming      = module.naming.names
  by_type     = module.naming.by_type
  region      = var.region
  region_code = local.region_codes[var.region]
  input = {
    topology    = local.input.topology
    tenant      = local.input.tenant
    environment = local.input.environment
    region      = local.input.region
    repo        = local.input.repo
  }

  address_space = local.address_space
  subnets       = local.subnets

  enable_default_route      = local.enable_default_route
  default_route_next_hop_ip = local.hub_firewall_private_ip
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = local.enable_peering ? 1 : 0

  name                         = "peer-sp01-to-hub-npd"
  resource_group_name          = module.network.resource_group_name
  virtual_network_name         = module.network.vnet_name
  remote_virtual_network_id    = local.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
