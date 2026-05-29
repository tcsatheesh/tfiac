# T039 - root-stack-level snapshot for prd.

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

run "snapshot_prd" {
  command = plan

  # See plan_snapshot_npd.tftest.hcl for the rationale on inlining.
  assert {
    condition     = "log-shd-shd-hub-prd-swc-001" == output.workspace_name
    error_message = "Root-stack workspace_name (prd) diverges from committed snapshot."
  }

  assert {
    condition     = "rg-log-shd-hub-prd-swc-001" == output.resource_group_name
    error_message = "Root-stack resource_group_name (prd) diverges from committed snapshot."
  }
}
