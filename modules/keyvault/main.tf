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

  # C-050 (FR-041) — private-by-default. When the private endpoint is enabled
  # the vault rejects all public network traffic (default_action = Deny) while
  # still permitting trusted Azure services (bypass = AzureServices); the vault
  # is then reachable only via the PE below. When disabled the prior public
  # behaviour is preserved byte-for-byte (public access on, default_action Allow).
  public_network_access_enabled = var.private_endpoint_enabled ? false : true

  network_acls {
    default_action = var.private_endpoint_enabled ? "Deny" : "Allow"
    bypass         = "AzureServices"
  }
}

# C-050 (Amendment 2026-06-03) — private endpoint (FR-041). When
# var.private_endpoint_enabled is true the vault is reachable only from the
# spoke VNet: public_network_access_enabled is false (above), the NIC lands in
# var.private_endpoint_subnet_id, the private_service_connection targets the
# vault with subresource group id "vault", and the private_dns_zone_group
# registers A-records in the hub privatelink.vaultcore.azure.net zone
# (var.private_dns_zone_ids). Required so the vault stays reachable only from
# the spoke VNet (006 FR-041).
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
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  lifecycle {
    precondition {
      condition     = var.private_endpoint_subnet_id != null && length(var.private_dns_zone_ids) > 0
      error_message = "C-050 / FR-041 — private_endpoint_enabled=true requires a non-null private_endpoint_subnet_id and a non-empty private_dns_zone_ids list."
    }
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
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
