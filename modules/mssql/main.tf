# Azure SQL logical server + database, private-by-default and Entra-ONLY.
# public_network_access_enabled is ALWAYS false; the server is reachable only
# through the always-on private endpoint below. azuread_authentication_only
# removes SQL-auth (no admin login/password, no secret anywhere).
resource "azurerm_mssql_server" "this" {
  name                          = var.canonical_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tags                          = var.tags
  version                       = local.config.server_version
  minimum_tls_version           = local.config.minimum_tls_version
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = var.entra_admin_login
    object_id                   = var.entra_admin_object_id
    tenant_id                   = var.entra_admin_tenant_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_database" "this" {
  name           = local.database_name
  server_id      = azurerm_mssql_server.this.id
  sku_name       = local.config.database_sku_name
  collation      = local.config.database_collation
  max_size_gb    = local.config.database_max_size_gb
  zone_redundant = local.config.database_zone_redundant
  tags           = var.tags
}

# Default diagnostic settings to the shared hub LA (C-014 parity). SQL
# diagnostics attach to the DATABASE (not the logical server).
resource "azurerm_monitor_diagnostic_setting" "to_hub_la" {
  count                      = var.diagnostic_settings_enabled ? 1 : 0
  name                       = "to-hub-la"
  target_resource_id         = azurerm_mssql_database.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "Basic"
  }
}

# Always-on private endpoint. subresource "sqlServer" -> the server; A-records
# register in the hub privatelink.database.windows.net zone.
resource "azurerm_private_endpoint" "this" {
  name                = local.pe_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.pe_name}-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
