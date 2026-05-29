# T036 - LOG-INV-1 - region hard-pinned to "swc".

variables {
  subscription_id   = "00000000-0000-0000-0000-000000000000"
  region            = "neu"
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

run "wrong_region_fails" {
  command = plan

  expect_failures = [
    var.region,
  ]
}
