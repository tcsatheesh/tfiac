# T039 [US3] - disabling every catalogue key leaves zone_ids empty but the
# RG is still emitted (edge case "Catalogue is entirely disabled").

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  region          = "swc"
  repo            = "tcsatheesh/tfiac"
  topology        = "hub"
  tenant          = "hub"
  environment     = "prd"
  custom_zones    = []
  disable_catalogue_zones = [
    "blob", "file", "queue", "table", "dfs", "web", "vault", "acr",
    "openai", "cogsvc", "search", "cosmos-sql", "webapp", "automation",
    "monitor", "oms", "ods", "agentsvc", "aml-api", "notebooks",
    "appconfig", "servicebus", "eventgrid", "iothub", "iothub-dps",
  ]
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "catalogue_fully_disabled" {
  command = plan

  assert {
    condition     = length(output.zone_ids) == 0
    error_message = "Disabling every catalogue key must leave zone_ids empty. Got: ${jsonencode(keys(output.zone_ids))}."
  }

  assert {
    condition     = length(output.zone_names) == 0
    error_message = "Disabling every catalogue key must leave zone_names empty."
  }

  assert {
    condition     = output.resource_group_name == "rg-dns-shd-hub-prd-swc-001"
    error_message = "RG name must still be emitted even when zone set is empty."
  }
}
