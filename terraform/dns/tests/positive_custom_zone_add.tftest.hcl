# T023 [US2] — positive_custom_zone_add (FR-016, FR-024..FR-026)
#
# Add one custom zone alongside the full catalogue → exactly 26 zones,
# the custom FQDN appears keyed by itself.

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

run "custom_zone_extends_catalogue" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "_github_org/_github_repo"
    custom_zones            = ["internal.contoso.local"]
    disable_catalogue_zones = []
    topology                = "hub"
    tenant                  = "hub"
    environment             = "prd"
  }

  assert {
    condition     = length(output.zone_ids) == 26
    error_message = "Expected 25 catalogue + 1 custom = 26 zones (FR-024)."
  }

  assert {
    condition     = contains(keys(output.zone_ids), "internal.contoso.local")
    error_message = "Custom FQDN must be present in zone_ids keyed by itself (FR-025)."
  }

  assert {
    condition     = output.zone_names["internal.contoso.local"] == "internal.contoso.local"
    error_message = "Custom zone name in zone_names must equal the FQDN (FR-025)."
  }
}
