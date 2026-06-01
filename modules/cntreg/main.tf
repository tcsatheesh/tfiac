resource "azurerm_container_registry" "this" {
  name                          = var.canonical_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tags                          = var.tags
  sku                           = local.effective_sku
  admin_enabled                 = local.config.admin_enabled
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
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# C-020 (Amendment 2026-06-01) — opt-in private endpoint (FR-029). When
# var.private_endpoint_enabled is true the registry is reachable only from the
# spoke VNet: public_network_access_enabled is false (above), the NIC lands in
# var.private_endpoint_subnet_id, the private_service_connection targets the
# registry with subresource group id "registry", and the private_dns_zone_group
# registers A-records in the hub privatelink.azurecr.io zone
# (var.private_dns_zone_ids).
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
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  lifecycle {
    precondition {
      condition     = var.private_endpoint_subnet_id != null && length(var.private_dns_zone_ids) > 0
      error_message = "C-020 / FR-029 — private_endpoint_enabled=true requires a non-null private_endpoint_subnet_id and a non-empty private_dns_zone_ids list."
    }
  }
}
