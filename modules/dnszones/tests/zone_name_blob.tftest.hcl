# T022 [US1] - the `blob` catalogue entry maps to the Microsoft-published
# FQDN verbatim (spec US1 scenario 2).

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = []
  disable_catalogue_zones = []
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "blob_zone_name" {
  command = plan

  assert {
    condition     = output.zone_names["blob"] == "privatelink.blob.core.windows.net"
    error_message = "Expected zone_names[\"blob\"] == \"privatelink.blob.core.windows.net\"; got ${output.zone_names["blob"]}."
  }
}
