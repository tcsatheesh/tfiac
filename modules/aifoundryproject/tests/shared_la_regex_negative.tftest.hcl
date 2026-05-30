# C-014 — asserts the shared LA workspace ID regex validator rejects a
# malformed input.

variables {
  canonical_name      = "aifp-shd-shd-sp01-dev-uks-001"
  resource_group_name = "rg-svc-shd-sp01-dev-uks-001"
  location            = "uksouth"
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = { managed_by = "terraform" }
    azure_max       = 32
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "not-a-resource-id"
  diagnostic_settings_enabled       = true
  parent_account_id                 = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

run "regex_rejects_malformed_workspace_id" {
  command         = plan
  expect_failures = [var.shared_log_analytics_workspace_id]
}
