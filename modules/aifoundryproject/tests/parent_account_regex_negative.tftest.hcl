# C-017 / FR-026 — asserts the parent_account_id regex validator rejects
# anything that is not a Microsoft.CognitiveServices/accounts resource ID.

variables {
  canonical_name      = "aifp-shd-shd-sp01-dev-uks-001"
  resource_group_name = "rg-svc-shd-sp01-dev-uks-001"
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = { managed_by = "terraform" }
    azure_max       = 32
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  # Legacy ML Workspace ID (kind=Hub) — must be rejected by the new C-017 regex.
  parent_account_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.MachineLearningServices/workspaces/aif-shd-shd-sp01-dev-uks-001"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

run "regex_rejects_ml_workspace_id" {
  command         = plan
  expect_failures = [var.parent_account_id]
}
