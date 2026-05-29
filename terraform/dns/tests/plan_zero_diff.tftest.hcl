# T024 [US1] - determinism: plan twice with identical inputs and confirm the
# emitted output maps are byte-identical (FR-026, SC-002). A true zero-diff
# requires an applied state, which needs Azure credentials; this test verifies
# the plan-time determinism precondition (same inputs -> same outputs).

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

run "plan_a" {
  command = plan
}

run "plan_b" {
  command = plan

  assert {
    condition     = jsonencode(run.plan_a.zone_names) == jsonencode(output.zone_names)
    error_message = "FR-026 / SC-002: zone_names must be identical across two plans of the same inputs."
  }

  assert {
    condition     = run.plan_a.resource_group_name == output.resource_group_name
    error_message = "FR-026 / SC-002: resource_group_name must be identical across two plans."
  }
}
