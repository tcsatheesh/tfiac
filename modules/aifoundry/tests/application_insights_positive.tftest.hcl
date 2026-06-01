# C-019 (Amendment 2026-06-01) — App Insights tracing positive path (FR-028).
# With application_insights_enabled = true the wrapper emits a single
# workspace-based azurerm_application_insights (anchored at the shared hub LA)
# and a single Microsoft.CognitiveServices/accounts/connections of category
# "AppInsights" (name "appinsights") parented by the account.

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

  # C-019 App Insights input.
  application_insights_enabled = true
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

run "application_insights_emitted" {
  command = plan

  assert {
    condition     = length(azurerm_application_insights.tracing) == 1
    error_message = "C-019: application_insights_enabled=true must emit exactly one azurerm_application_insights.tracing."
  }

  assert {
    condition     = azurerm_application_insights.tracing[0].name == "appi-aif-shd-shd-sp01-npd-uks-001"
    error_message = "C-019: App Insights name must be appi-<canonical_name>."
  }

  assert {
    condition     = azurerm_application_insights.tracing[0].workspace_id == var.shared_log_analytics_workspace_id
    error_message = "C-019: App Insights must be workspace-based and anchored at the shared hub LA workspace id."
  }

  assert {
    condition     = length(azapi_resource.appinsights_connection) == 1
    error_message = "C-019: application_insights_enabled=true must emit exactly one azapi_resource.appinsights_connection."
  }

  assert {
    condition     = azapi_resource.appinsights_connection[0].name == "appinsights"
    error_message = "C-019: the tracing connection must be named \"appinsights\" (RP name-pattern compliant)."
  }

  assert {
    condition     = azapi_resource.appinsights_connection[0].type == "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
    error_message = "C-019: the tracing connection must be a Microsoft.CognitiveServices/accounts/connections@2025-09-01."
  }

  assert {
    condition     = azapi_resource.appinsights_connection[0].body.properties.category == "AppInsights"
    error_message = "C-019: the tracing connection category must be \"AppInsights\"."
  }
}
