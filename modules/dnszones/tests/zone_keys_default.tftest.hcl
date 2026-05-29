# T021 [US1] - with reference inputs (empty custom/disable lists), zone_ids
# keys must equal the catalogue keys, sorted (FR-024, spec US1 scenario 1).

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

run "zone_ids_keys_equal_catalogue_keys" {
  command = plan

  assert {
    condition     = length(output.zone_ids) == 25
    error_message = "Expected 25 zone_ids entries (one per catalogue key); got ${length(output.zone_ids)}."
  }

  # zone_names is plan-time known and parallel to zone_ids per DNS-INV-10.
  assert {
    condition = sort(keys(output.zone_names)) == sort([
      "blob", "file", "queue", "table", "dfs", "web", "vault", "acr",
      "openai", "cogsvc", "search", "cosmos-sql", "webapp", "automation",
      "monitor", "oms", "ods", "agentsvc", "aml-api", "notebooks",
      "appconfig", "servicebus", "eventgrid", "iothub", "iothub-dps",
    ])
    error_message = "zone_names keys must equal the 25 catalogue keys (FR-024). Got: ${jsonencode(sort(keys(output.zone_names)))}."
  }
}
