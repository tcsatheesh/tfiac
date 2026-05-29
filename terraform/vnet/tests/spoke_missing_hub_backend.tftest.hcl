# T045 - VNET-INV-6: spoke role REQUIRES hub_state_backend.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000002"
  repo            = "tcsatheesh/tfiac"
  region          = "swc"
  tenant          = "sp01"
  environment     = "npd"
  role            = "spoke"
  usecase         = "shd"
  address_space   = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
  }
  # hub_state_backend intentionally omitted.
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}
mock_provider "azurerm" { alias = "hub" }
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "spoke_missing_hub_backend" {
  command = plan
  expect_failures = [
    var.hub_state_backend,
  ]
}
