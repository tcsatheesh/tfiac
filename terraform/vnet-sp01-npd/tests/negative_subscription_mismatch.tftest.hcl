mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      tenant_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      object_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      client_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
    }
  }
}

run "subscription_mismatch_fails" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    hub_vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-npd-sdc-001/providers/Microsoft.Network/virtualNetworks/vnet-hub-npd-sdc-001"
    hub_firewall_private_ip = "10.240.5.4"
  }

  expect_failures = [
    check.subscription_pinned,
  ]
}
