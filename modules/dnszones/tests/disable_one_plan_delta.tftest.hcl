# T044 - SC-004: disabling exactly one catalogue key after a baseline apply
# should remove exactly that one zone (asserted via the output key set).

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

run "disable_one" {
  command = plan

  variables {
    disable_catalogue_zones = ["acr"]
  }

  assert {
    condition     = length(run.baseline.zone_names) - length(output.zone_names) == 1
    error_message = "SC-004: disabling a single key must drop exactly 1 zone from the output set. Baseline=${length(run.baseline.zone_names)}, after_disable=${length(output.zone_names)}."
  }

  assert {
    condition     = !contains(keys(output.zone_names), "acr")
    error_message = "SC-004: 'acr' must be absent from zone_names after disabling."
  }

  assert {
    condition     = length(setsubtract(keys(run.baseline.zone_names), keys(output.zone_names))) == 1
    error_message = "SC-004: exactly one key must disappear; got ${length(setsubtract(keys(run.baseline.zone_names), keys(output.zone_names)))} dropped."
  }
}
