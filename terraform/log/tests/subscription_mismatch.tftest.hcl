# T037 - LOG-INV-5 / FR-109 - subscription_id must match the active provider's
# subscription. We supply 11111... in var.subscription_id but the mocked
# data.azurerm_client_config.current returns 00000... -> check.subscription_match
# fires.

variables {
  subscription_id   = "11111111-1111-1111-1111-111111111111"
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

run "subscription_mismatch_fails" {
  command = plan

  expect_failures = [
    check.subscription_match,
  ]
}
