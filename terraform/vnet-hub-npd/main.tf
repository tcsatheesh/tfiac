module "naming" {
  source = "../../modules/naming"
  input  = local.input
}

data "azurerm_client_config" "current" {}

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

  enable_bastion  = true
  enable_firewall = true

  # Wired post-firewall (depends on module.firewall.private_ip).
  enable_default_route      = true
  default_route_next_hop_ip = module.firewall.private_ip
}

module "bastion" {
  source = "../../modules/network/bastion"

  region              = var.region
  region_code         = local.region_codes[var.region]
  input               = { topology = local.input.topology, tenant = local.input.tenant, environment = local.input.environment, region = local.input.region, repo = local.input.repo }
  resource_group_name = module.network.resource_group_name
  subnet_id           = module.network.subnet_ids["bastion"]
}

module "firewall" {
  source = "../../modules/network/firewall"

  region                  = var.region
  region_code             = local.region_codes[var.region]
  input                   = { topology = local.input.topology, tenant = local.input.tenant, environment = local.input.environment, region = local.input.region, repo = local.input.repo }
  resource_group_name     = module.network.resource_group_name
  firewall_subnet_id      = module.network.subnet_ids["firewall"]
  firewall_mgmt_subnet_id = module.network.subnet_ids["firewall-mgmt"]
}
