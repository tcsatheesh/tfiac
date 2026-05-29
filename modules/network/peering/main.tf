# Constitution IX exception: native azurerm resources are required here because
# AVM cannot model both sides of a cross-subscription peering with a single
# provider. We declare two aliased providers and create one peering per side.

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider = azurerm.this

  name                         = format("peer-%s-to-hub", var.spoke_vnet_name)
  resource_group_name          = var.spoke_resource_group_name
  virtual_network_name         = var.spoke_vnet_name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider = azurerm.hub

  name                         = format("peer-hub-to-%s", var.spoke_vnet_name)
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = var.spoke_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
