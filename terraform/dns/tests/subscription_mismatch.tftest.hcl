# T049 - subscription mismatch hard-fail (FR-029, DNS-INV-8, SC-005).

variables {
  subscription_id         = "11111111-1111-1111-1111-111111111111"
  region                  = "swc"
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

run "subscription_mismatch_fails" {
  command = plan

  expect_failures = [
    check.subscription_match,
  ]
}
