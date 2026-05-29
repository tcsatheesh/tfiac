# T038 - root-stack-level snapshot for npd.

variables {
  subscription_id   = "00000000-0000-0000-0000-000000000000"
  region            = "swc"
  repo              = "tcsatheesh/tfiac"
  topology          = "hub"
  tenant            = "hub"
  environment       = "npd"
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

run "snapshot_npd" {
  command = plan

  # Expected values mirror the snapshot fixtures committed under
  # modules/loganalytics/tests/fixtures/. file() in terraform test cannot read
  # files outside the module under test, so we inline them here and rely on
  # the wrapper-module tests to enforce the fixture binding.
  assert {
    condition     = "log-shd-shd-hub-npd-swc-001" == output.workspace_name
    error_message = "Root-stack workspace_name (npd) diverges from committed snapshot."
  }

  assert {
    condition     = "rg-log-shd-hub-npd-swc-001" == output.resource_group_name
    error_message = "Root-stack resource_group_name (npd) diverges from committed snapshot."
  }
}
