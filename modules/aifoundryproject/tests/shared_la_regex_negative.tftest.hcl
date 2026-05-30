variables {
  canonical_name      = "aifp-shd-shd-sp01-npd-uks-001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags = {
    managed_by = "terraform"
  }
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = { managed_by = "terraform" }
    azure_max       = 64
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "not-a-resource-id"
  diagnostic_settings_enabled       = true
  hub_resource_id                   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-npd-uks-001/providers/Microsoft.MachineLearningServices/workspaces/aif-shd-shd-sp01-npd-uks-001"
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_subscription.current
    values = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000001"
    }
  }
}
mock_provider "azapi" {}

run "regex_rejects_malformed_workspace_id" {
  command         = plan
  expect_failures = [var.shared_log_analytics_workspace_id]
}
