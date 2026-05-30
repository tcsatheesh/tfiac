resource "azurerm_storage_account" "this" {
  name                            = var.canonical_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  tags                            = var.tags
  account_tier                    = local.config.account_tier
  account_replication_type        = local.config.account_replication_type
  min_tls_version                 = local.config.min_tls_version
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
}

# C-014 (Amendment 2026-05-31) — default diagnostic settings to shared hub LA.
# The storage *account* resource itself exposes only metrics in its diagnostic
# settings surface; per-service logs (blob/file/queue/table) hang off
# sub-resources like ${id}/blobServices/default. category_group = "allLogs"
# returns 400 BadRequest here. AllMetrics is also rejected on Microsoft.Storage
# accounts (Azure expands it to Capacity + Transaction post-create and the next
# plan churns). Enumerate the two supported categories explicitly so the plan
# is idempotent. Operators can opt out via var.diagnostic_settings_enabled.
resource "azurerm_monitor_diagnostic_setting" "to_hub_la" {
  count                      = var.diagnostic_settings_enabled ? 1 : 0
  name                       = "to-hub-la"
  target_resource_id         = azurerm_storage_account.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_metric {
    category = "Capacity"
  }
  enabled_metric {
    category = "Transaction"
  }
}
