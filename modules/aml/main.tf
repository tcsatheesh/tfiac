# AML workspace: hand-rolled via azapi to sidestep the AVM module's
# cross-resource (app insights / keyvault / storage) hard-required IDs.
# Operators wire those in via `overrides.body.properties` for v2.
data "azurerm_subscription" "current" {}

resource "azapi_resource" "this" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-04-01"
  name      = var.canonical_name
  location  = var.location
  parent_id = "${data.azurerm_subscription.current.id}/resourceGroups/${var.resource_group_name}"
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku        = { name = local.config.sku_name }
    properties = {}
  }
}

# C-014 (Amendment 2026-05-31) — default diagnostic settings to shared hub LA.
# enabled_log { category_group = "allLogs" } + metric { category = "AllMetrics" }
# enables the full surface dynamically without enumerating per-RP categories
# (which would require data.azurerm_monitor_diagnostic_categories and create a
# first-apply chicken-and-egg cycle). Operators can opt out via
# var.diagnostic_settings_enabled = false (escape hatch — document in PR body).
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
