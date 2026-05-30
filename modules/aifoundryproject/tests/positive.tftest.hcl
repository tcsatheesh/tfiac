variables {
  canonical_name      = "aifp-shd-shd-sp01-npd-uks-001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags = {
    managed_by      = "terraform"
    tenant          = "sp01"
    environment     = "npd"
    region          = "uksouth"
    repo            = "tcsatheesh/tfiac"
    usecase         = "shd"
    stack_purpose   = "svc"
    service_purpose = "shd"
  }
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags = {
      managed_by      = "terraform"
      tenant          = "sp01"
      environment     = "npd"
      region          = "uksouth"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "shd"
    }
    azure_max = 64
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
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

run "canonical_name_flows_through" {
  command = plan

  assert {
    condition     = var.canonical_name == "aifp-shd-shd-sp01-npd-uks-001"
    error_message = "canonical_name diverged from engine reference."
  }
}

run "diag_wired_to_shared_la" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.to_hub_la) == 1
    error_message = "C-014: diagnostic_settings_enabled defaults to true but no diag resource was emitted."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.to_hub_la[0].log_analytics_workspace_id == var.shared_log_analytics_workspace_id
    error_message = "C-014: diag log_analytics_workspace_id diverged from the input."
  }
}
