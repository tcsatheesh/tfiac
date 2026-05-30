# FR-218 case a / C16.8 a — link count equals zone count.

mock_provider "azurerm" {}
mock_provider "azurerm" { alias = "dns" }

variables {
  vnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  vnet_name = "vnet-net-shd-hub-npd-swc-001"
  zone_ids = {
    "blob"      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    "vaultcore" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    "monitor"   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.monitor.azure.com"
  }
  tags = { "owner" = "test" }
}

run "links_count_matches_zones" {
  command = plan

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.this) == 3
    error_message = "FR-218 a: expected 3 vnet-links (one per zone in zone_ids), got a different count."
  }
}
