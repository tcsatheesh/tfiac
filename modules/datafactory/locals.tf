locals {
  defaults = {
    # Managed VNet IR compute scale. Reserved compute is billed for the whole TTL
    # window, so defaults are the smallest usable size; tune per instance via
    # var.overrides (e.g. the portal "Medium" copy preset is 64 DIU).
    managed_ir_copy_compute_diu     = 4
    managed_ir_copy_compute_ttl_min = 20
    managed_ir_pipeline_nodes       = 1
    managed_ir_external_nodes       = 1
    managed_ir_pipeline_ttl_min     = 20
  }
  config = merge(local.defaults, var.overrides)

  has_kv      = var.link_key_vault
  has_storage = var.link_storage
  has_sql     = var.link_sql

  # Managed-VNet integration runtime that outbound managed private endpoints
  # route through.
  managed_ir_name = "ManagedVnetIR"

  # Reserved-child PE names derived in-module (see cosmosdb/mssql pattern).
  pe_name_data   = "pep-${var.canonical_name}"
  pe_name_portal = "pep-portal-${var.canonical_name}"

  # Derived endpoint for the Storage blob linked service (MI auth).
  blob_endpoint = var.storage_account_name != null ? "https://${var.storage_account_name}.blob.core.windows.net" : null

  # Target resource ids of every linked service (managed-PE connections to
  # approve on the target side).
  managed_pe_targets = compact([
    var.link_key_vault ? var.key_vault_id : "",
    var.link_storage ? var.storage_account_id : "",
    var.link_sql ? var.sql_server_id : "",
  ])

  # ADF system-assigned managed identity is registered in Entra under the
  # factory's own name; the T-SQL grant creates a contained user by that name.
  sql_connection_string = local.has_sql ? "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${var.sql_server_fqdn};Initial Catalog=${var.sql_database_name}" : null
}
