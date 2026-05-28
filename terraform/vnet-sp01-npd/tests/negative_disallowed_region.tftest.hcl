mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

run "disallowed_region_rejected" {
  command = plan

  variables {
    subscription_id             = "00000000-0000-0000-0000-000000000000"
    region                      = "eastus"
    repo                        = "tcsatheesh/tfiac"
    hub_vnet_id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-npd-sdc-001/providers/Microsoft.Network/virtualNetworks/vnet-hub-npd-sdc-001"
    hub_firewall_private_ip     = "10.240.5.4"
    hub_peered_spoke_vnet_names = ["vnet-sp01-npd-sdc-001"]
  }

  expect_failures = [
    var.region,
  ]
}
