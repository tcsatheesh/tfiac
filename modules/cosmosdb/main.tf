# FR-032 (Amendment 2026-06-02) — Azure Cosmos DB account (SQL/NoSQL API),
# private-by-default. Provisioned as the Bring-Your-Own thread store for a
# Foundry Hosted-Agent capability host (CosmosDB connection), but usable as a
# standalone selectable service. public_network_access_enabled is ALWAYS false;
# the account is reachable only through the always-on private endpoint below.
resource "azurerm_cosmosdb_account" "this" {
  name                          = var.canonical_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tags                          = var.tags
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = false
  local_authentication_disabled = local.config.local_authentication_disabled
  free_tier_enabled             = local.config.free_tier_enabled
  automatic_failover_enabled    = local.config.automatic_failover_enabled

  consistency_policy {
    consistency_level = local.config.consistency_level
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

# C-014 (Amendment 2026-05-31) — default diagnostic settings to shared hub LA.
# category_group = "allLogs" + AllMetrics enables the full Cosmos DB surface
# dynamically without enumerating per-RP categories. Operators can opt out via
# var.diagnostic_settings_enabled = false (escape hatch — document in PR body).
resource "azurerm_monitor_diagnostic_setting" "to_hub_la" {
  count                      = var.diagnostic_settings_enabled ? 1 : 0
  name                       = "to-hub-la"
  target_resource_id         = azurerm_cosmosdb_account.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "Requests"
  }
}

# FR-032 — always-on private endpoint. The NIC lands in
# var.private_endpoint_subnet_id, the private_service_connection targets the
# account with subresource group id "Sql" (Core/NoSQL API), and the
# private_dns_zone_group registers A-records in the hub
# privatelink.documents.azure.com zone (var.private_dns_zone_ids).
resource "azurerm_private_endpoint" "this" {
  name                = local.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.pe_name}-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_cosmosdb_account.this.id
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
