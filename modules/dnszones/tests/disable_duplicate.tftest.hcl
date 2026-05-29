# T040 [US3] - duplicate key in disable_catalogue_zones hard-fails
# (FR-019, DNS-INV-6, SC-005).

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = []
  disable_catalogue_zones = ["acr", "acr"]
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "duplicate_disable_key_fails" {
  command = plan

  expect_failures = [
    var.disable_catalogue_zones,
  ]
}
