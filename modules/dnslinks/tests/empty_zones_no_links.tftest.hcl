# FR-218 case d / C16.8 d — empty zone_ids ⇒ zero links, plan succeeds.

mock_provider "azurerm" {}
mock_provider "azurerm" { alias = "dns" }

variables {
  vnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  vnet_name = "vnet-net-shd-hub-npd-swc-001"
  zone_ids  = {}
}

run "empty_zones_emits_no_links" {
  command = plan

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.this) == 0
    error_message = "FR-218 d: zone_ids = {} must emit zero links."
  }
}
