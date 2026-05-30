# FR-213 / FR-218 case c / C16.3 / C16.8 c — every link is named "vnetlink-${var.vnet_name}".

mock_provider "azurerm" {}
mock_provider "azurerm" { alias = "dns" }

variables {
  vnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  vnet_name = "vnet-net-shd-hub-npd-swc-001"
  zone_ids = {
    "blob"      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    "vaultcore" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
  }
}

run "link_name_matches_vnetlink_prefix_plus_vnet_name" {
  command = plan

  assert {
    condition = alltrue([
      for l in azurerm_private_dns_zone_virtual_network_link.this :
      l.name == "vnetlink-vnet-net-shd-hub-npd-swc-001"
    ])
    error_message = "FR-213 / C16.3: at least one link's name does not equal \"vnetlink-${var.vnet_name}\"."
  }
}
