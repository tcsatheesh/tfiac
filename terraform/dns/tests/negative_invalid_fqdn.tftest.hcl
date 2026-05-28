# T025 [US2] — negative_invalid_fqdn (FR-016)
#
# Malformed FQDN must be rejected by var.custom_zones FQDN-regex validation
# on the ROOT stack (T028).

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

run "invalid_fqdn_rejected" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = ["not_a_valid_dns_name"]
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }

  expect_failures = [
    var.custom_zones,
  ]
}
