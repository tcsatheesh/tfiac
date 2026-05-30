# Asserts the canonical_name empty-string validator hard-fails at plan time.

variables {
  canonical_name      = ""
  resource_group_name = "rg-svc-shd-sp01-dev-uks-001"
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = null
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 32
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  parent_account_id                 = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

run "empty_canonical_name_rejected" {
  command         = plan
  expect_failures = [var.canonical_name]
}
