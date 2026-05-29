# T018 - reference variables + the 5 mock_provider blocks every test in this
# directory expects. This file is NOT auto-shared across .tftest.hcl files
# (terraform test does not merge variables/provider blocks across files), so
# each test file declares its own copies. Kept here as living documentation
# of the canonical baseline.

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
  daily_quota_gb    = -1
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "baseline_validate" {
  command = plan
}
