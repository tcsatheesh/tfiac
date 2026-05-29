# T048 - SC-007 snapshot determinism at the root-stack boundary.

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

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "zone_names_match_snapshot" {
  command = plan

  assert {
    condition     = jsondecode(file("${path.module}/../../modules/dnszones/tests/fixtures/zone_names_snapshot.json")) == output.zone_names
    error_message = "Root-stack zone_names diverges from the committed snapshot."
  }

  assert {
    condition     = length(setsubtract(toset(jsondecode(file("${path.module}/../../modules/dnszones/tests/fixtures/zone_ids_snapshot.json"))), toset(keys(output.zone_ids)))) == 0 && length(setsubtract(toset(keys(output.zone_ids)), toset(jsondecode(file("${path.module}/../../modules/dnszones/tests/fixtures/zone_ids_snapshot.json"))))) == 0
    error_message = "Root-stack zone_ids key set diverges from the committed snapshot."
  }
}
