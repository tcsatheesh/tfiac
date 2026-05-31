# T037 [US3] - disabling a single catalogue key drops it from the effective set.

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = []
  disable_catalogue_zones = ["acr"]
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "acr_disabled" {
  command = plan

  assert {
    condition     = !contains(keys(output.zone_ids), "acr")
    error_message = "acr key must NOT appear in zone_ids when disabled. Got: ${jsonencode(keys(output.zone_ids))}."
  }

  assert {
    condition     = length(output.zone_ids) == 25
    error_message = "Expected 25 zone_ids entries (26 catalogue - 1 disabled); got ${length(output.zone_ids)}."
  }
}
