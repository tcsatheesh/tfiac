variables {
  canonical_name      = ""
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags                = {}
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = null
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 64
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  hub_resource_id                   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-npd-uks-001/providers/Microsoft.MachineLearningServices/workspaces/aif-shd-shd-sp01-npd-uks-001"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

run "empty_canonical_name_rejected" {
  command         = plan
  expect_failures = [var.canonical_name]
}
