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

# `terraform test` escalates failed check assertions to test failures, which
# is exactly what we want — gives us a structural test for the reminder
# mechanism. This test asserts the warning *fires* when the hub side has
# not been updated yet (override list is empty).
variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  region          = "swedencentral"
  repo            = "_github_org/_github_repo"
  role            = "spoke"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "npd"
  address_space   = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "logic-app"      = "10.240.2.128/28"
    "function-app"   = "10.240.2.144/28"
    "preprod-logic"  = "10.240.2.160/28"
    "preprod-func"   = "10.240.2.176/28"
  }
  hub_vnet_id_override                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-npd-sdc-001/providers/Microsoft.Network/virtualNetworks/vnet-hub-npd-sdc-001"
  hub_firewall_private_ip_override     = "10.240.5.4"
  hub_peered_spoke_vnet_names_override = []
}

run "warns_when_hub_missing_entry" {
  command = plan

  expect_failures = [
    check.hub_peering_registered,
  ]
}
