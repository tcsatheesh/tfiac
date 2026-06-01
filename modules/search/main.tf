resource "azurerm_search_service" "this" {
  name                          = var.canonical_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tags                          = var.tags
  sku                           = local.config.sku
  replica_count                 = local.config.replica_count
  partition_count               = local.config.partition_count
  public_network_access_enabled = var.private_endpoint_enabled ? false : true
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
  target_resource_id         = azurerm_search_service.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# C-039 (Amendment 2026-06-02) — opt-in private endpoint (FR-035). When
# var.private_endpoint_enabled is true the AI Search service is reachable only
# from the spoke VNet: public_network_access_enabled is false (above), the NIC
# lands in var.private_endpoint_subnet_id, the private_service_connection
# targets the service with subresource group id "searchService", and the
# private_dns_zone_group registers A-records in the hub
# privatelink.search.windows.net zone (var.private_dns_zone_ids).
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
    private_connection_resource_id = azurerm_search_service.this.id
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  lifecycle {
    precondition {
      condition     = var.private_endpoint_subnet_id != null && length(var.private_dns_zone_ids) > 0
      error_message = "C-039 / FR-035 — private_endpoint_enabled=true requires a non-null private_endpoint_subnet_id and a non-empty private_dns_zone_ids list."
    }
  }
}
