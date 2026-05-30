# FR-212 / FR-218 case b / C16.2 / C16.8 b — registration_enabled is false on every link.

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

run "registration_disabled_on_every_link" {
  command = plan

  assert {
    condition = alltrue([
      for l in azurerm_private_dns_zone_virtual_network_link.this :
      l.registration_enabled == false
    ])
    error_message = "FR-212 / C16.2: at least one link has registration_enabled != false. Hard-coded literal in main.tf must NEVER be inverted (privatelink.* zones must not auto-register VM hostnames)."
  }
}
