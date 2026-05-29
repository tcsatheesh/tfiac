# T047 - SC-007 snapshot determinism test (wrapper-module side).
# Compares the plan-time outputs against committed fixtures so catalogue drift
# is caught at PR time.

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

run "zone_names_match_snapshot" {
  command = plan

  assert {
    condition     = jsondecode(file("${path.module}/tests/fixtures/zone_names_snapshot.json")) == output.zone_names
    error_message = "zone_names diverges from tests/fixtures/zone_names_snapshot.json. Regenerate per tests/fixtures/README.md if the catalogue edit was intentional."
  }
}

run "zone_ids_keys_match_snapshot" {
  command = plan

  assert {
    condition     = length(setsubtract(toset(jsondecode(file("${path.module}/tests/fixtures/zone_ids_snapshot.json"))), toset(keys(output.zone_names)))) == 0 && length(setsubtract(toset(keys(output.zone_names)), toset(jsondecode(file("${path.module}/tests/fixtures/zone_ids_snapshot.json"))))) == 0
    error_message = "Public key set diverges from tests/fixtures/zone_ids_snapshot.json (compared via zone_names since zone_ids is computed at apply). Regenerate per tests/fixtures/README.md if the catalogue edit was intentional."
  }
}
