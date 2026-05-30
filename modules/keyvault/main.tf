data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = var.canonical_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tags                       = var.tags
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = local.config.sku_name
  purge_protection_enabled   = local.config.purge_protection_enabled
  soft_delete_retention_days = local.config.soft_delete_retention_days
  rbac_authorization_enabled = local.config.rbac_authorization_enabled
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
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
