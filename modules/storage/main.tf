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
  public_network_access_enabled   = var.private_endpoint_enabled ? false : true
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

# C-035 (Amendment 2026-06-02) — opt-in private endpoint (FR-034). When
# var.private_endpoint_enabled is true the account is reachable only from the
# spoke VNet: public_network_access_enabled is false (above), the NIC lands in
# var.private_endpoint_subnet_id, the private_service_connection targets the
# account with subresource group id "blob", and the private_dns_zone_group
# registers A-records in the hub privatelink.blob.core.windows.net zone
# (var.private_dns_zone_ids). Needed so the storage account stays reachable
# only from the spoke VNet (006 FR-034).
resource "azurerm_private_endpoint" "this" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = local.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.pe_name}-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  lifecycle {
    precondition {
      condition     = var.private_endpoint_subnet_id != null && length(var.private_dns_zone_ids) > 0
      error_message = "C-035 / FR-034 — private_endpoint_enabled=true requires a non-null private_endpoint_subnet_id and a non-empty private_dns_zone_ids list."
    }
  }
}
