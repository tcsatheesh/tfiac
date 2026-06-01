# C-019 / FR-028 — Foundry App Insights tracing happy path.
# enable_aifoundry_application_insights = true with an `aifoundry` selection
# wires application_insights_enabled = true into module.aifoundry. The hub LA
# id is resolved from the (stubbed) terraform/log/ remote state. The PE feature
# stays at its default off, so no vnet/dns remote state is required.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "aifoundry" },
    { type = "aifoundry_project" },
  ]
  overrides                             = {}
  enable_aifoundry_application_insights = true
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

run "aifoundry_appinsights_wired" {
  command = plan

  assert {
    condition     = var.enable_aifoundry_application_insights == true
    error_message = "C-019: enable_aifoundry_application_insights must be true for this happy-path run."
  }

  assert {
    condition     = length([for k, v in module.aifoundry : v if v != null]) == 1
    error_message = "C-019: exactly one aifoundry module instance must be created when an aifoundry is selected."
  }
}
