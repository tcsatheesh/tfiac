# C-017 / FR-026 — aifoundry_project requires exactly one aifoundry
# (Cognitive Services Foundry account) selection in the same services
# stack. Asserts that selecting aifoundry_project without aifoundry
# hard-fails at plan time.
#
# The failure surfaces from the variable validation on
# `var.parent_account_id` inside modules/aifoundryproject/variables.tf:
# `one([])` returns null which fails the
# Microsoft.CognitiveServices/accounts resource-ID regex.
# The defence-in-depth `check "aifoundry_project_requires_account"` in
# terraform/services/check.tf is also present but does not fire first;
# variable validation runs before check aggregation.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "uks"
  usecase         = "shd"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "aifoundry_project" }
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

run "rejects_aifoundry_project_without_account" {
  command = plan
  expect_failures = [
    check.aifoundry_project_requires_account,
    azurerm_resource_group.svc,
  ]
}
