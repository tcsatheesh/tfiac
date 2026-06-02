# C-013 (Amendment 2026-05-31) — apim is hub-only.
# Asserts that selecting apim on a spoke stack hard-fails at plan time.
# The failure surfaces from:
#   1. check.apim_hub_only (terraform/services/check.tf), AND
#   2. lifecycle.precondition on azurerm_resource_group.svc
#      (terraform/services/main.tf), AND
#   3. lifecycle.precondition on terraform_data.topology_hub_only_guard
#      inside modules/apim (modules/apim/check.tf).
# terraform_test reports the first hit; we expect_failures on the
# wrapper guard since module-level preconditions fire before root-level
# `check {}` aggregation in terraform 1.13.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "uks"
  usecase         = "shd"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "apim" }
  ]
  overrides          = {}
  private_by_default = false
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

run "rejects_apim_on_spoke" {
  command = plan
  # On spoke + apim selected: the root-level check.apim_hub_only fires
  # AND the precondition on azurerm_resource_group.svc fires. The apim
  # wrapper is gated by topology in main.tf so its precondition is NOT
  # reached from this stack (covered by modules/apim/tests/topology_spoke_rejected.tftest.hcl).
  expect_failures = [
    check.apim_hub_only,
    azurerm_resource_group.svc,
  ]
}
