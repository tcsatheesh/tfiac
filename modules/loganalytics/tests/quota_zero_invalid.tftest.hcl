# T045 - US3 - daily_quota_gb = 0 must hard-fail (LOG-INV-7, FR-105).

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
  daily_quota_gb    = 0
}

mock_provider "azurerm" {}
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
