# T030 [US2] - shadowing a catalogue FQDN via custom_zones is a hard-fail at
# plan time (FR-017, DNS-INV-3, SC-005).

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = ["privatelink.blob.core.windows.net"]
  disable_catalogue_zones = []
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "shadowing_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
