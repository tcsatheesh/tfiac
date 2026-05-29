# T048 - LOG-INV-7 root-stack copy - quota=0 hard-fails here too.

variables {
  subscription_id   = "00000000-0000-0000-0000-000000000000"
  region            = "swc"
  repo              = "tcsatheesh/tfiac"
  topology          = "hub"
  tenant            = "hub"
  environment       = "npd"
  retention_in_days = 30
  daily_quota_gb    = 0
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

run "quota_zero_rejected" {
  command = plan

  expect_failures = [
    var.daily_quota_gb,
  ]
}
