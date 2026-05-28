# T030 [US3] — positive_disable_catalogue_zone (FR-018)
#
# Disable one catalogue key → 24 zones, the disabled key absent.

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

run "disable_acr_yields_24_zones" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = []
    disable_catalogue_zones = ["acr"]
  }

  assert {
    condition     = length(output.zone_ids) == 24
    error_message = "Disabling one catalogue key must reduce zone count by 1 (24 remain)."
  }

  assert {
    condition     = lookup(output.zone_ids, "acr", null) == null
    error_message = "Disabled key \"acr\" must be absent from zone_ids (FR-018)."
  }
}
