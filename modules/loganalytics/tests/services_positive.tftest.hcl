# T021 - services-stack-consumption positive: when the loganalytics wrapper
# is invoked from the services stack (with stack_purpose="log" passed
# through to keep the pre-existing wrapper interface intact), the engine
# emits the same workspace canonical-name shape that lands in the v1
# selectable type catalogue (data-model § 5).

variables {
  input = {
    tenant        = "sp01"
    environment   = "npd"
    region        = "uks"
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

run "services_stack_consumption_emits_expected_workspace_name" {
  command = plan

  assert {
    condition     = output.workspace_name == "log-shd-shd-sp01-npd-uks-001"
    error_message = "services-stack-consumption: workspace_name diverged from data-model § 5 (expected 'log-shd-shd-sp01-npd-uks-001')."
  }

  assert {
    condition     = output.resource_group_name == "rg-log-shd-sp01-npd-uks-001"
    error_message = "services-stack-consumption: resource_group_name diverged (expected 'rg-log-shd-sp01-npd-uks-001')."
  }
}
