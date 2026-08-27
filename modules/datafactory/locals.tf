locals {
  defaults = {}
  config   = merge(local.defaults, var.overrides)

  has_kv      = var.link_key_vault
  has_storage = var.link_storage
  has_sql     = var.link_sql

  # Managed-VNet integration runtime that outbound managed private endpoints
  # route through.
  managed_ir_name = "ManagedVnetIR"

  # Reserved-child PE names derived in-module (see cosmosdb/mssql pattern).
  pe_name_data   = "pep-${var.canonical_name}"
  pe_name_portal = "pep-portal-${var.canonical_name}"

  # Derived FQDNs / endpoints for managed private endpoints + linked services.
  kv_fqdn       = var.key_vault_name != null ? "${var.key_vault_name}.vault.azure.net" : null
  blob_fqdn     = var.storage_account_name != null ? "${var.storage_account_name}.blob.core.windows.net" : null
  blob_endpoint = var.storage_account_name != null ? "https://${var.storage_account_name}.blob.core.windows.net" : null

  # ADF system-assigned managed identity is registered in Entra under the
  # factory's own name; the T-SQL grant creates a contained user by that name.
  sql_connection_string = local.has_sql ? "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${var.sql_server_fqdn};Initial Catalog=${var.sql_database_name}" : null
}
