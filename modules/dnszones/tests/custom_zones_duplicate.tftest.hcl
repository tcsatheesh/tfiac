# T032 [US2] - duplicate FQDN in custom_zones fails the variable validation
# (FR-019, DNS-INV-4, SC-005).

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = ["a.example.com", "a.example.com"]
  disable_catalogue_zones = []
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "duplicate_fqdn_fails" {
  command = plan

  expect_failures = [
    var.custom_zones,
  ]
}
