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
    subscription_id = "00000000-0000-0000-0000-000000000000"
    region          = "eastus"
    repo            = "tcsatheesh/tfiac"
    topology        = "hub"
    tenant          = "hub"
    environment     = "npd"
  }

  expect_failures = [
    var.region,
  ]
}
