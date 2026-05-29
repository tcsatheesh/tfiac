# T046 - US3 - daily_quota_gb negative (other than -1 sentinel) must hard-fail.

variables {
  input = {
    tenant        = "hub"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "log"
    repo          = "tcsatheesh/tfiac"
  }
  workspace_key     = "central"
  retention_in_days = 30
  daily_quota_gb    = -2
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "quota_minus_two_rejected" {
  command = plan

  expect_failures = [
    var.daily_quota_gb,
  ]
}
