# T025 - US1 - plan twice with prd reference inputs; second plan must be
# byte-for-byte identical to the first (FR-110).

variables {
  subscription_id   = "00000000-0000-0000-0000-000000000000"
  region            = "swc"
  repo              = "tcsatheesh/tfiac"
  topology          = "hub"
  tenant            = "hub"
  environment       = "prd"
  retention_in_days = 30
  daily_quota_gb    = -1
  workspace_key     = "central"
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
    condition     = run.plan_a.workspace_name == output.workspace_name
    error_message = "workspace_name diverged between two consecutive plans (prd)."
  }

  assert {
    condition     = run.plan_a.resource_group_name == output.resource_group_name
    error_message = "resource_group_name diverged between two consecutive plans (prd)."
  }
}
