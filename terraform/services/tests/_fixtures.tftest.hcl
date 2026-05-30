# C-013 + C-014 (Amendment 2026-05-31) — shared test scaffolding for the
# services root stack.
#
# NOTE (per spec.md C-014): the root stack reads the shared hub LA workspace
# id via `data "terraform_remote_state" "hub_log"` (terraform/services/data.log.tf).
# That backend is not reachable inside terraform_test, so every test file in
# this directory MUST `override_data` the remote_state lookup with a stub
# workspace id. Terraform 1.13 does not auto-share blocks across .tftest.hcl
# files, so the override is repeated inline in each test rather than imported
# from here. This file documents the canonical fixture values and runs a
# baseline `plan` to catch wiring regressions early.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "hub"
  tenant          = "hub"
  environment     = "npd"
  region          = "uks"
  usecase         = "shd"
  repo            = "tcsatheesh/tfiac"
  services        = []
  overrides       = {}
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

run "baseline_plan_succeeds" {
  command = plan
}
