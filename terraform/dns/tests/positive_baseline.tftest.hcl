# T013 [US1] — positive_baseline (FR-024 / FR-025)
#
# Day-one catalogue only (no customs, no disables). Asserts:
#   - output.zone_ids has exactly 25 keys
#   - output.zone_names["blob"] is the Microsoft FQDN
#   - output.resource_group_name is the engine-emitted canonical
#
# The azurerm provider is mocked — the config-set arguments (name, location)
# pass through; computed attributes (id) get arbitrary mock values that we
# do not assert against here.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

run "baseline_25_catalogue_zones" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = []
    disable_catalogue_zones = []
  }

  assert {
    condition     = length(output.zone_ids) == 25
    error_message = "Expected exactly 25 catalogue zones in zone_ids (FR-011)."
  }

  assert {
    condition     = output.zone_names["blob"] == "privatelink.blob.core.windows.net"
    error_message = "zone_names[\"blob\"] must equal the Microsoft-published FQDN privatelink.blob.core.windows.net (FR-011)."
  }

  assert {
    condition     = output.resource_group_name == "rg-hub-prd-sdc-001"
    error_message = "resource_group_name must be the engine-emitted canonical rg-hub-prd-sdc-001 (FR-009)."
  }

  assert {
    condition     = contains(keys(output.zone_names), "cosmos-sql") && contains(keys(output.zone_names), "iothub-dps")
    error_message = "Catalogue keys with hyphens (cosmos-sql, iothub-dps) must round-trip through the output map."
  }
}
