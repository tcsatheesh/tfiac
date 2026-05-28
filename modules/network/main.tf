###############################################################################
# modules/network/main.tf — RG + vnet + subnets + NSGs + route table + assoc.
# Provider-less; inherits azurerm from the root stack (Constitution VI).
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.region
  tags     = local.baseline_tags
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  tags                = local.baseline_tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = local.subnet_name_for[each.key]
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]
  service_endpoints    = local.subnet_roles[each.key].service_endpoints

  dynamic "delegation" {
    for_each = local.subnet_roles[each.key].delegations
    content {
      name = delegation.value.name
      service_delegation {
        name = delegation.value.service_delegation.name
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = toset(local.nsg_roles)

  name                = local.nsg_name_for[each.key]
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  tags                = merge(local.baseline_tags, { subnet_role = each.key })
}

# Baseline rules required by Azure for AzureBastionSubnet.
locals {
  bastion_baseline_rules = contains(local.nsg_roles, "bastion") ? [
    { name = "AllowHttpsInbound", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "443", source_address_prefix = "Internet", destination_address_prefix = "*" },
    { name = "AllowGatewayManagerInbound", priority = 130, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "443", source_address_prefix = "GatewayManager", destination_address_prefix = "*" },
    { name = "AllowLoadBalancerInbound", priority = 140, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "443", source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*" },
    { name = "AllowBastionHostCommunication", priority = 150, direction = "Inbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_range = "8080,5701", source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork" },
    { name = "AllowSshRdpOutbound", priority = 100, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_range = "22,3389", source_address_prefix = "*", destination_address_prefix = "VirtualNetwork" },
    { name = "AllowAzureCloudOutbound", priority = 110, direction = "Outbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "443", source_address_prefix = "*", destination_address_prefix = "AzureCloud" },
    { name = "AllowBastionCommunicationOutbound", priority = 120, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_range = "8080,5701", source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork" },
    { name = "AllowGetSessionInformation", priority = 130, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_range = "80", source_address_prefix = "*", destination_address_prefix = "Internet" },
  ] : []

  # Combined: baseline (per role) + caller-provided extras.
  all_rules_by_role = {
    for r in local.nsg_roles :
    r => concat(
      r == "bastion" ? local.bastion_baseline_rules : [],
      try(var.extra_nsg_rules[r], []),
    )
  }

  # Flattened for for_each.
  flat_rules = merge([
    for role, rules in local.all_rules_by_role : {
      for rule in rules : "${role}|${rule.name}" => merge(rule, { role = role })
    }
  ]...)
}

resource "azurerm_network_security_rule" "this" {
  for_each = local.flat_rules

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this[each.value.role].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = toset(local.nsg_roles)

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_route_table" "this" {
  count = length(local.rt_roles) > 0 ? 1 : 0

  name                = local.rt_name
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.baseline_tags
}

resource "azurerm_route" "default_via_firewall" {
  count = length(local.rt_roles) > 0 && var.enable_default_route ? 1 : 0

  name                   = "route-to-firewall"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.this[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.default_route_next_hop_ip
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = toset(local.rt_roles)

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id
}
