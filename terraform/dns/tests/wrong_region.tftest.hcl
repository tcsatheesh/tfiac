# T050 - FR-001 region hard-pin.

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "uks"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = []
  disable_catalogue_zones = []
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "wrong_region_fails" {
  command = plan

  expect_failures = [
    var.region,
  ]
}
