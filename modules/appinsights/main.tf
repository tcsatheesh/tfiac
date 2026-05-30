resource "azurerm_application_insights" "this" {
  name                = var.canonical_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  application_type    = local.config.application_type
  retention_in_days   = local.config.retention_in_days
  # C-014 (Amendment 2026-05-31) — anchor the workspace-based AI resource at
  # the SHARED hub Log Analytics workspace (provisioned by terraform/log/).
  workspace_id = var.shared_log_analytics_workspace_id
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
  target_resource_id         = azurerm_application_insights.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
