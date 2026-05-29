# T038 [US3] - disable_catalogue_zones with an unknown key hard-fails
# (FR-018, DNS-INV-5, SC-005).

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = []
  disable_catalogue_zones = ["frobnicate"]
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "unknown_disable_key_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
