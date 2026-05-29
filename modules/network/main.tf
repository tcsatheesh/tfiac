###############################################################################
# modules/network/main.tf — AVM-backed RG + NSGs + Route Table + VNet.
# Wraps:
#   * Azure/avm-res-network-networksecuritygroup/azurerm   0.5.1
#   * Azure/avm-res-network-routetable/azurerm             0.5.0
#   * Azure/avm-res-network-virtualnetwork/azurerm         0.17.1
# RG is intentionally bare (Constitution IX permits direct azurerm for RGs).
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.region
  tags     = local.baseline_tags
}

# ─── NSGs (one per role) ─────────────────────────────────────────────────────

module "nsg" {
  source   = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version  = "0.5.1"
  for_each = toset(local.nsg_roles)

  name                = local.nsg_name_for[each.key]
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  tags                = merge(local.baseline_tags, { subnet_role = each.key })
  security_rules      = local.nsg_security_rules_for[each.key]
  enable_telemetry    = false
}

# ─── Route Table (only created when at least one role wants one) ─────────────

module "route_table" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "0.5.0"
  count   = length(local.rt_roles) > 0 ? 1 : 0

  name                = local.rt_name
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.baseline_tags
  enable_telemetry    = false

  # NOTE: routes are intentionally NOT declared here. Adding the
  # default-route inside the AVM route_table module pulls the firewall
  # private IP (an apply-time attribute) into the subnet→route_table
  # dependency chain, which forms a graph cycle with the firewall→subnet
  # dependency. We attach the route below as a separate bare
  # azurerm_route resource that depends only on the already-created
  # route_table + the firewall, breaking the cycle.
  routes = {}
}

# Default route (0.0.0.0/0 → firewall private IP). Kept outside the
# route_table AVM module to avoid a cycle with the firewall module
# (firewall needs subnets; subnets attach to route_table; route_table
# would otherwise need the firewall IP).
resource "azurerm_route" "default_via_firewall" {
  count = length(module.route_table) > 0 && var.enable_default_route ? 1 : 0

  name                   = "route-to-firewall"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = local.rt_name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.default_route_next_hop_ip

  depends_on = [module.route_table]
}

# ─── VNet + Subnets (incl. NSG / RT / SE / delegation associations) ──────────

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  name             = local.vnet_name
  location         = var.region
  parent_id        = azurerm_resource_group.this.id
  address_space    = var.address_space
  tags             = local.baseline_tags
  enable_telemetry = false

  subnets = {
    for r in local.requested_roles : r => {
      name             = local.subnet_name_for[r]
      address_prefixes = [var.subnets[r]]
      service_endpoints_with_location = length(local.subnet_roles[r].service_endpoints) > 0 ? [
        for se in local.subnet_roles[r].service_endpoints : { service = se }
      ] : null
      delegations = length(local.subnet_roles[r].delegations) > 0 ? [
        for d in local.subnet_roles[r].delegations : {
          name = d.name
          service_delegation = {
            name = d.service_delegation.name
          }
        }
      ] : null
      network_security_group = local.subnet_roles[r].add_nsg ? {
        id = module.nsg[r].resource_id
      } : null
      route_table = local.subnet_roles[r].add_route_table && length(module.route_table) > 0 ? {
        id = module.route_table[0].resource_id
      } : null
    }
  }
}
