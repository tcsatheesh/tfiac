# T026 [US2] — negative_duplicate_entries (FR-019)
#
# Duplicates within custom_zones must be rejected by the root-stack
# de-dup validation (T028).

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

run "duplicate_custom_zones_rejected" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = ["a.b.com", "a.b.com"]
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }

  expect_failures = [
    var.custom_zones,
  ]
}
