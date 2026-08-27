# T028 [US2] - adding a single custom FQDN surfaces a new (fqdn,fqdn) row.

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = ["internal.example.com"]
  disable_catalogue_zones = []
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "custom_zone_appears" {
  command = plan

  assert {
    condition     = contains(keys(output.zone_names), "internal.example.com")
    error_message = "Custom FQDN must appear as a key in zone_names (FR-024). Got: ${jsonencode(keys(output.zone_names))}."
  }

  assert {
    condition     = output.zone_names["internal.example.com"] == "internal.example.com"
    error_message = "zone_names[<custom_fqdn>] must equal the FQDN itself (FR-024). Got: ${output.zone_names["internal.example.com"]}."
  }

  # Catalogue stays intact alongside the new entry.
  assert {
    condition     = length(output.zone_names) == 30
    error_message = "Expected 29 catalogue + 1 custom = 30 zone_names entries; got ${length(output.zone_names)}."
  }
}
