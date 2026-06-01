# C-019 (Amendment 2026-06-01) — App Insights tracing default-off path (FR-028).
# With application_insights_enabled at its default false the wrapper emits
# NEITHER the azurerm_application_insights NOR the connection — day-one
# behaviour is preserved.

variables {
  canonical_name      = "aif-shd-shd-sp01-npd-uks-001"
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
    service_type    = "aifoundry"
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
    azure_max = 260
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
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

run "application_insights_absent_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_application_insights.tracing) == 0
    error_message = "C-019: with application_insights_enabled at default false, no App Insights must be emitted."
  }

  assert {
    condition     = length(azapi_resource.appinsights_connection) == 0
    error_message = "C-019: with application_insights_enabled at default false, no tracing connection must be emitted."
  }
}
