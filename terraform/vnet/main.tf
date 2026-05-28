###############################################################################
# terraform/vnet/main.tf  (feature 004 — role-driven hub | spoke stack)
###############################################################################

module "naming" {
  source = "../../modules/naming"
  input  = local.input
}

data "azurerm_client_config" "current" {}

# ─── spoke: read hub remote state ────────────────────────────────────────────
# Skipped entirely when role=hub or when test overrides are supplied.

data "terraform_remote_state" "hub" {
  count   = local.is_spoke && var.hub_vnet_id_override == "" ? 1 : 0
  backend = "azurerm"
  config  = var.hub_state_backend
}

locals {
  hub_vnet_id             = var.hub_vnet_id_override != "" ? var.hub_vnet_id_override : (local.is_spoke ? try(data.terraform_remote_state.hub[0].outputs.vnet_id, "") : "")
  hub_firewall_private_ip = var.hub_firewall_private_ip_override != "" ? var.hub_firewall_private_ip_override : (local.is_spoke ? try(data.terraform_remote_state.hub[0].outputs.firewall_private_ip, "") : "")
  hub_peered_spokes       = length(var.hub_peered_spoke_vnet_names_override) > 0 ? var.hub_peered_spoke_vnet_names_override : (local.is_spoke ? try(data.terraform_remote_state.hub[0].outputs.peered_spoke_vnet_names, []) : [])
}

# ─── shared network module ───────────────────────────────────────────────────

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

  address_space = var.address_space
  subnets       = var.subnets

  enable_bastion  = local.is_hub
  enable_firewall = local.is_hub

  enable_default_route      = local.is_hub ? true : (local.hub_firewall_private_ip != "")
  default_route_next_hop_ip = local.is_hub ? module.firewall[0].private_ip : local.hub_firewall_private_ip
}

# ─── hub-only add-ons ────────────────────────────────────────────────────────

module "bastion" {
  source = "../../modules/network/bastion"
  count  = local.is_hub ? 1 : 0

  region              = var.region
  region_code         = local.region_codes[var.region]
  input               = { topology = local.input.topology, tenant = local.input.tenant, environment = local.input.environment, region = local.input.region, repo = local.input.repo }
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.subnet_ids["bastion"]
}

module "firewall" {
  source = "../../modules/network/firewall"
  count  = local.is_hub ? 1 : 0

  region                  = var.region
  region_code             = local.region_codes[var.region]
  input                   = { topology = local.input.topology, tenant = local.input.tenant, environment = local.input.environment, region = local.input.region, repo = local.input.repo }
  resource_group_name     = module.network.resource_group_name
  firewall_subnet_id      = module.network.subnet_ids["firewall"]
  firewall_mgmt_subnet_id = module.network.subnet_ids["firewall-mgmt"]
}

# ─── peering: hub side (one entry per registered spoke) ──────────────────────

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.is_hub ? var.spoke_peerings : {}

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = module.network.resource_group_name
  virtual_network_name         = module.network.vnet_name
  remote_virtual_network_id    = each.value.remote_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ─── peering: spoke side (one leg, this spoke -> hub) ────────────────────────

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = local.is_spoke && local.hub_vnet_id != "" ? 1 : 0

  name                         = "peer-${var.tenant}-${var.environment}-to-hub-${var.environment}"
  resource_group_name          = module.network.resource_group_name
  virtual_network_name         = module.network.vnet_name
  remote_virtual_network_id    = local.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
