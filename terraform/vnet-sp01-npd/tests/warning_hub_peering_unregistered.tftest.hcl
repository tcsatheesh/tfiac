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

# In normal operation check.hub_peering_registered emits only a warning,
# but `terraform test` escalates failed check assertions to test failures
# (which is exactly what we want — it gives us a structural test for the
# reminder mechanism). This test asserts the warning *fires* when the
# hub side has not been updated yet.
run "warns_when_hub_missing_entry" {
  command = plan

  variables {
    subscription_id             = "00000000-0000-0000-0000-000000000000"
    region                      = "swedencentral"
    repo                        = "tcsatheesh/tfiac"
    hub_vnet_id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-npd-sdc-001/providers/Microsoft.Network/virtualNetworks/vnet-hub-npd-sdc-001"
    hub_firewall_private_ip     = "10.240.5.4"
    hub_peered_spoke_vnet_names = []
  }

  expect_failures = [
    check.hub_peering_registered,
  ]
}
