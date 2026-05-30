# AI Foundry project: hand-rolled via azapi until a stable AVM module ships.
# C-017 (Amendment 2026-05-30) — rebased from the legacy
# Microsoft.MachineLearningServices/workspaces (kind=Project) RP onto
# Microsoft.CognitiveServices/accounts/projects, parented directly by the
# Cognitive Services Foundry account (var.parent_account_id). The project
# inherits location, tags, and public-access from the parent account; those
# fields are NOT re-declared at the child level.

resource "azapi_resource" "this" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-09-01"
  name      = var.canonical_name
  parent_id = var.parent_account_id

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      displayName = var.canonical_name
      description = "Foundry project ${var.canonical_name}"
    }
  }

  response_export_values = ["id"]
}

# C-014 (Amendment 2026-05-31) — default diagnostic settings to shared hub LA.
resource "azurerm_monitor_diagnostic_setting" "to_hub_la" {
  count                      = var.diagnostic_settings_enabled ? 1 : 0
  name                       = "to-hub-la"
  target_resource_id         = azapi_resource.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
