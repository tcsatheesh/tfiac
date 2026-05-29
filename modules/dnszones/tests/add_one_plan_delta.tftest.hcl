# T045 - SC-003: adding exactly one custom zone after a baseline apply should
# introduce exactly that one new zone (asserted via the output key set).

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

run "baseline" {
  command = plan
}

run "add_one" {
  command = plan

  variables {
    custom_zones = ["internal.example.com"]
  }

  assert {
    condition     = length(output.zone_names) - length(run.baseline.zone_names) == 1
    error_message = "SC-003: adding a single custom zone must introduce exactly 1 new zone. Baseline=${length(run.baseline.zone_names)}, after_add=${length(output.zone_names)}."
  }

  assert {
    condition     = contains(keys(output.zone_names), "internal.example.com")
    error_message = "SC-003: 'internal.example.com' must be present in zone_names after adding."
  }

  assert {
    condition     = length(setsubtract(keys(output.zone_names), keys(run.baseline.zone_names))) == 1
    error_message = "SC-003: exactly one key must appear; got ${length(setsubtract(keys(output.zone_names), keys(run.baseline.zone_names)))} added."
  }
}
