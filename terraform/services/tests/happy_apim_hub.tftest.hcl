# C-013 (Amendment 2026-05-31) — happy path: apim on a hub stack plans cleanly.
# Mirrors reject_apim_spoke.tftest.hcl with topology=hub / tenant=hub so the
# C-013 guards stay quiescent and the wrapper instantiates normally.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "hub"
  tenant          = "hub"
  environment     = "npd"
  region          = "uks"
  usecase         = "shd"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "apim" }
  ]
  overrides = {}
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000099"
      client_id       = "00000000-0000-0000-0000-000000000098"
      object_id       = "00000000-0000-0000-0000-000000000097"
    }
  }
  mock_data "azurerm_subscription" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000"
      subscription_id       = "00000000-0000-0000-0000-000000000000"
      tenant_id             = "00000000-0000-0000-0000-000000000099"
      display_name          = "mock-subscription"
      location_placement_id = "Public_2014-09-01"
      quota_id              = "PayAsYouGo_2014-09-01"
      spending_limit        = "Off"
      state                 = "Enabled"
      tags                  = {}
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

override_data {
  target = data.terraform_remote_state.hub_log
  values = {
    outputs = {
      workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
    }
  }
}

run "apim_on_hub_plans_cleanly" {
  command = plan

  assert {
    condition     = length(keys(module.apim)) == 1
    error_message = "happy_apim_hub: expected exactly one apim wrapper instance, got ${length(keys(module.apim))}."
  }

  assert {
    condition     = output.shared_la_workspace_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
    error_message = "happy_apim_hub: shared_la_workspace_id output did not resolve to the mocked terraform_remote_state value (C-014 wiring broken)."
  }
}
