# Azure Data Factory, private-by-default: Managed VNet on, public access off,
# system-assigned identity. Reached inbound only through the private endpoints
# below; reaches SQL/KV/Storage outbound only through managed private endpoints.
resource "azurerm_data_factory" "this" {
  name                            = var.canonical_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  tags                            = var.tags
  managed_virtual_network_enabled = true
  public_network_enabled          = false

  identity {
    type = "SystemAssigned"
  }
}

# Managed-VNet Azure integration runtime; managed private endpoints below route
# egress through this runtime's managed virtual network.
resource "azurerm_data_factory_integration_runtime_azure" "managed" {
  name                    = local.managed_ir_name
  data_factory_id         = azurerm_data_factory.this.id
  location                = var.location
  virtual_network_enabled = true
}

# copyComputeScaleProperties / pipelineExternalComputeScaleProperties TTLs are
# not exposed by the azurerm IR resource, so patch them onto the same runtime.
resource "azapi_update_resource" "managed_ir_compute_scale" {
  type        = "Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01"
  resource_id = azurerm_data_factory_integration_runtime_azure.managed.id

  body = {
    properties = {
      type = "Managed"
      typeProperties = {
        computeProperties = {
          copyComputeScaleProperties = {
            dataIntegrationUnit = local.config.managed_ir_copy_compute_diu
            timeToLive          = local.config.managed_ir_copy_compute_ttl_min
          }
          pipelineExternalComputeScaleProperties = {
            numberOfPipelineNodes = local.config.managed_ir_pipeline_nodes
            numberOfExternalNodes = local.config.managed_ir_external_nodes
            timeToLive            = local.config.managed_ir_pipeline_ttl_min
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        local.config.managed_ir_copy_compute_diu >= 4
        && local.config.managed_ir_copy_compute_diu <= 256
        && local.config.managed_ir_copy_compute_diu % 4 == 0
      )
      error_message = "managed_ir_copy_compute_diu must be a multiple of 4 between 4 and 256 (Azure rejects other values)."
    }

    precondition {
      condition = (
        local.config.managed_ir_copy_compute_ttl_min >= 5
        && local.config.managed_ir_pipeline_ttl_min >= 5
      )
      error_message = "managed VNet IR time-to-live values must be at least 5 minutes."
    }

    precondition {
      condition = (
        local.config.managed_ir_pipeline_nodes >= 1
        && local.config.managed_ir_external_nodes >= 1
      )
      error_message = "managed_ir_pipeline_nodes and managed_ir_external_nodes must each be at least 1."
    }
  }
}

# Default diagnostics to the shared hub LA (C-014 parity).
resource "azurerm_monitor_diagnostic_setting" "to_hub_la" {
  count                      = var.diagnostic_settings_enabled ? 1 : 0
  name                       = "to-hub-la"
  target_resource_id         = azurerm_data_factory.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ----- Inbound private endpoints (private-by-default) -----
# `dataFactory` sub-resource -> privatelink.datafactory.azure.net.
resource "azurerm_private_endpoint" "data" {
  name                = local.pe_name_data
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.pe_name_data}-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_data_factory.this.id
    subresource_names              = ["dataFactory"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.datafactory_private_dns_zone_ids
  }
}

# `portal` sub-resource -> privatelink.adf.azure.net (ADF Studio private access).
resource "azurerm_private_endpoint" "portal" {
  name                = local.pe_name_portal
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.pe_name_portal}-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_data_factory.this.id
    subresource_names              = ["portal"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.portal_private_dns_zone_ids
  }
}

# ----- Outbound managed private endpoints (ADF managed VNet -> targets) -----
resource "azurerm_data_factory_managed_private_endpoint" "kv" {
  count              = local.has_kv ? 1 : 0
  name               = "mpe-kv-${var.canonical_name}"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.key_vault_id
  subresource_name   = "vault"
}

resource "azurerm_data_factory_managed_private_endpoint" "storage" {
  count              = local.has_storage ? 1 : 0
  name               = "mpe-sto-${var.canonical_name}"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.storage_account_id
  subresource_name   = "blob"
}

resource "azurerm_data_factory_managed_private_endpoint" "sql" {
  count              = local.has_sql ? 1 : 0
  name               = "mpe-sql-${var.canonical_name}"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.sql_server_id
  subresource_name   = "sqlServer"
}

# Approve the ADF managed private endpoint connections on the target resources.
# ADF managed PEs always land as `Pending` on the target; the DEPLOYMENT (not a
# human) approves them so the managed-identity linked services become usable.
# Runs on the in-VNet deploy runner via `az` (the CI principal has Contributor
# on the targets). Idempotent: skips targets whose connection is already
# approved. Re-runs only when a managed PE changes.
resource "terraform_data" "approve_managed_pes" {
  count = (var.link_key_vault || var.link_storage || var.link_sql) ? 1 : 0

  triggers_replace = {
    kv      = local.has_kv ? azurerm_data_factory_managed_private_endpoint.kv[0].id : ""
    storage = local.has_storage ? azurerm_data_factory_managed_private_endpoint.storage[0].id : ""
    sql     = local.has_sql ? azurerm_data_factory_managed_private_endpoint.sql[0].id : ""
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI not found on the deploy runner; required to approve ADF managed private endpoints." >&2; exit 1; }
      for t in ${join(" ", local.managed_pe_targets)}; do
        for i in 1 2 3 4 5; do
          cid=$(az network private-endpoint-connection list --id "$t" --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id | [0]" -o tsv 2>/dev/null || true)
          if [ -n "$cid" ]; then
            echo "approving ADF managed PE connection: $cid"
            az network private-endpoint-connection approve --id "$cid" --description "ADF managed private endpoint (approved by deployment)" -o none
            break
          fi
          sleep 8
        done
      done
    EOT
  }

  depends_on = [
    azurerm_data_factory_managed_private_endpoint.kv,
    azurerm_data_factory_managed_private_endpoint.storage,
    azurerm_data_factory_managed_private_endpoint.sql,
  ]
}

# ----- Linked services (authenticate via the ADF managed identity) -----
resource "azurerm_data_factory_linked_service_key_vault" "kv" {
  count           = local.has_kv ? 1 : 0
  name            = "ls-keyvault"
  data_factory_id = azurerm_data_factory.this.id
  key_vault_id    = var.key_vault_id
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "storage" {
  count                    = local.has_storage ? 1 : 0
  name                     = "ls-storage"
  data_factory_id          = azurerm_data_factory.this.id
  service_endpoint         = local.blob_endpoint
  use_managed_identity     = true
  integration_runtime_name = azurerm_data_factory_integration_runtime_azure.managed.name
}

# AzureSqlDatabase via system-assigned managed identity. Uses the generic
# custom-service resource so the MI authentication type is expressed exactly.
resource "azurerm_data_factory_linked_custom_service" "sql" {
  count           = local.has_sql ? 1 : 0
  name            = "ls-sql"
  data_factory_id = azurerm_data_factory.this.id
  type            = "AzureSqlDatabase"
  description     = "Azure SQL Database linked service (system-assigned managed identity auth)."
  integration_runtime {
    name = azurerm_data_factory_integration_runtime_azure.managed.name
  }
  type_properties_json = jsonencode({
    connectionString   = local.sql_connection_string
    authenticationType = "SystemAssignedManagedIdentity"
  })
}

# ----- Control-plane RBAC for the ADF managed identity on KV + Storage -----
resource "azurerm_role_assignment" "kv_secrets_user" {
  count                = local.has_kv ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  count                = local.has_storage ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# ----- Data-plane grant: ADF managed identity -> contained SQL DB user -----
# Least-privilege (db_datareader/db_datawriter/db_ddladmin). Runs from the
# in-VNet deploy runner via sqlcmd, authenticating with Entra as the SQL server
# administrator. The runner's system-assigned managed identity is the SQL admin
# (set on the server), so the grant uses ActiveDirectoryManagedIdentity. The
# contained user is created WITH OBJECT_ID to avoid a Microsoft Graph lookup
# (no Directory Readers requirement on the SQL server identity). Idempotent.
resource "terraform_data" "sql_grant" {
  count = local.has_sql && var.sql_grant_enabled ? 1 : 0

  triggers_replace = {
    server = var.sql_server_fqdn
    db     = var.sql_database_name
    adf    = var.canonical_name
    oid    = azurerm_data_factory.this.identity[0].principal_id
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      command -v sqlcmd >/dev/null 2>&1 || {
        echo "ERROR: sqlcmd (go-sqlcmd) not found on the deploy runner; required for the ADF->SQL grant." >&2
        exit 1
      }
      sqlcmd -S "${var.sql_server_fqdn}" -d "${var.sql_database_name}" \
        --authentication-method ActiveDirectoryManagedIdentity -b -Q \
        "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${var.canonical_name}') CREATE USER [${var.canonical_name}] FROM EXTERNAL PROVIDER WITH OBJECT_ID='${azurerm_data_factory.this.identity[0].principal_id}'; ALTER ROLE db_datareader ADD MEMBER [${var.canonical_name}]; ALTER ROLE db_datawriter ADD MEMBER [${var.canonical_name}]; ALTER ROLE db_ddladmin ADD MEMBER [${var.canonical_name}];"
    EOT
  }

  depends_on = [
    azurerm_data_factory.this,
    azurerm_data_factory_managed_private_endpoint.sql,
  ]
}
