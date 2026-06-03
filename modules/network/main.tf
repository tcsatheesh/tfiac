# Wrapper main: naming engine + RG + vnet+subnets + per-role NSGs + RT.
# Bastion/firewall submodules wired conditionally for role=="hub".

module "naming" {
  source = "../naming"

  input    = var.input
  services = local.engine_services
  children = local.engine_children
}

module "rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.4"

  name             = local.rg_canonical_name
  location         = local.region_full
  tags             = module.naming.names[local.rg_canonical_name].tags
  enable_telemetry = false
}

# ----- NSG per role (only for roles where role_catalogue.needs_nsg = true) -----

module "nsg" {
  source   = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version  = "~> 0.4"
  for_each = toset(local.nsg_roles)

  name                = local.nsg_canonical_names[each.key]
  location            = local.region_full
  resource_group_name = module.rg.name
  tags                = module.naming.names[local.nsg_canonical_names[each.key]].tags
  enable_telemetry    = false
}

# ----- vnet (creates subnets too via AVM module) -----

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.8"

  name             = local.vnet_canonical_name
  location         = local.region_full
  parent_id        = module.rg.resource_id
  address_space    = var.address_space
  tags             = module.naming.names[local.vnet_canonical_name].tags
  enable_telemetry = false

  subnets = {
    for r, cidr in var.subnets : local.role_catalogue[r].abbr3 => {
      name             = local.subnet_canonical_names[r]
      address_prefixes = [cidr]

      network_security_group = (
        local.role_catalogue[r].needs_nsg
        ? { id = module.nsg[r].resource_id }
        : null
      )

      route_table = (
        local.role_catalogue[r].needs_route_table && local.route_table_active
        ? { id = module.rt.resource_id }
        : null
      )

      service_endpoints_with_location = [
        for ep in local.role_catalogue[r].service_endpoints : {
          service = ep
          # Microsoft.Storage is server-side normalised from ["*"] to a
          # regional pair by Azure (FR-225). Other endpoints (e.g.
          # Microsoft.KeyVault) are stored as-is, so ["*"] is fine.
          locations = ep == "Microsoft.Storage" ? lookup(local.storage_se_locations, local.region_full, ["*"]) : ["*"]
        }
      ]

      delegations = [
        for d in local.role_catalogue[r].delegation : {
          name = replace(d, "/", "-")
          service_delegation = {
            name = d
          }
        }
      ]
    }
  }
}

# ----- route table (one per vnet; routes vary by role) -----

module "rt" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "~> 0.3"

  name                          = local.rt_canonical_name
  location                      = local.region_full
  resource_group_name           = module.rg.name
  tags                          = module.naming.names[local.rt_canonical_name].tags
  enable_telemetry              = false
  bgp_route_propagation_enabled = false

  # Both hub and spoke route 0.0.0.0/0 -> hub firewall private IP (FR-210).
  # Spoke takes the address via var.hub_firewall_private_ip (remote state);
  # hub takes it from its own in-vnet firewall submodule output. The hub
  # AzureFirewallSubnet / AzureFirewallManagementSubnet do not attach this
  # route table (needs_route_table = false in role_catalogue), so there is
  # no routing loop.
  routes = (
    var.role == "spoke" && var.hub_firewall_private_ip != null
    ? {
      to-firewall = {
        name                   = "udr-defaultroute"
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = var.hub_firewall_private_ip
      }
    }
    : var.role == "hub" && var.enable_hub_firewall && var.enable_hub_default_route
    ? {
      to-firewall = {
        name                   = "udr-defaultroute"
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = module.firewall[0].private_ip
      }
    }
    : {}
  )
}

# ----- bastion (hub only) -----

module "bastion" {
  source = "./bastion"
  count  = var.role == "hub" ? 1 : 0

  name              = local.bastion_canonical_name
  location          = local.region_full
  resource_group_id = module.rg.resource_id
  subnet_id         = module.vnet.subnets[local.role_catalogue["bastion"].abbr3].resource_id
  public_ip_name    = local.pip_canonical_names.bas
  tags              = module.naming.names[local.bastion_canonical_name].tags
  public_ip_tags    = module.naming.names[local.pip_canonical_names.bas].tags
}

# ----- firewall (hub only) -----

module "firewall" {
  source = "./firewall"
  count  = var.role == "hub" && var.enable_hub_firewall ? 1 : 0

  name                = local.firewall_canonical_name
  location            = local.region_full
  resource_group_name = module.rg.name
  data_subnet_id      = module.vnet.subnets[local.role_catalogue["firewall"].abbr3].resource_id
  mgmt_subnet_id      = module.vnet.subnets[local.role_catalogue["firewall-mgmt"].abbr3].resource_id
  data_pip_name       = local.pip_canonical_names.afw
  mgmt_pip_name       = local.pip_canonical_names.afm
  tags                = module.naming.names[local.firewall_canonical_name].tags
  pip_data_tags       = module.naming.names[local.pip_canonical_names.afw].tags
  pip_mgmt_tags       = module.naming.names[local.pip_canonical_names.afm].tags
  firewall_sku_tier   = var.firewall_sku_tier
}
