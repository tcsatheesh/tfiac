# AI Foundry account: hand-rolled via azapi until a stable AVM module ships.
# C-017 (Amendment 2026-05-30) — rebased from the legacy
# Microsoft.MachineLearningServices/workspaces (kind=Hub) RP onto
# Microsoft.CognitiveServices/accounts (kind=AIServices,
# allowProjectManagement=true) to match the admin-1364-resource shape.
# Foundry accounts manage their own underlying storage and secrets; no
# sibling Key Vault / Storage Account inputs are required.
data "azurerm_subscription" "current" {}

resource "azapi_resource" "this" {
  # FR-040 (Amendment 2026-06-02) — the injection path pins the account to
  # `2025-04-01-preview`, the only API version with a Microsoft-proven
  # network-secured injection reference (sample 15 ▸ ai-account-identity.bicep);
  # two live applies on the GA `2025-09-01` failed at account create. The
  # version is gated on injection so every NON-injected account keeps the GA
  # version (changing `type` force-replaces — unacceptable for already-deployed
  # accounts; injection-on accounts are recreated by design, VC-1). VC-9.
  type      = local.network_injection_enabled ? "Microsoft.CognitiveServices/accounts@2025-04-01-preview" : "Microsoft.CognitiveServices/accounts@2025-09-01"
  name      = var.canonical_name
  location  = var.location
  parent_id = "${data.azurerm_subscription.current.id}/resourceGroups/${var.resource_group_name}"
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind       = "AIServices"
    sku        = { name = "S0" }
    properties = local.account_properties
  }

  response_export_values = ["id", "properties.endpoints"]

  # C-043 (Amendment 2026-06-02) — Hosted-Agent network injection (FR-033)
  # provisions a managed agent network behind the account and routinely takes
  # longer than the azapi default 30-minute create deadline (observed ~30m+ →
  # "context deadline exceeded"). Raise the create/update budget so the injected
  # account can finish provisioning; the value is a harmless upper bound for the
  # plain (non-injected) path, which still returns in a few minutes.
  timeouts {
    create = "90m"
    update = "90m"
    delete = "30m"
  }

  # FR-031 step 4 (C-022..C-024) — when Hosted-Agent network injection is on,
  # the account MUST be private (injection is meaningless on a public account)
  # and all four agent inputs (subnet + the three BYO resource ids) MUST be
  # present. Defence-in-depth on top of the per-variable validators.
  lifecycle {
    precondition {
      condition = !var.network_injection_enabled || (
        var.private_endpoint_enabled &&
        var.agent_subnet_id != null &&
        var.agent_storage_account_id != null &&
        var.agent_cosmosdb_account_id != null &&
        var.agent_search_service_id != null
      )
      error_message = "FR-031 — network_injection_enabled=true requires private_endpoint_enabled=true and non-null agent_subnet_id, agent_storage_account_id, agent_cosmosdb_account_id, and agent_search_service_id."
    }

    # FR-044 / FR-045 — when a connection toggle is on its resource id must be
    # supplied (the toggle is the known-at-plan gate; the id carries the value).
    precondition {
      condition     = !var.account_storage_connection_enabled || var.account_storage_account_id != null
      error_message = "FR-044 — account_storage_connection_enabled=true requires a non-null account_storage_account_id."
    }

    precondition {
      condition     = !var.keyvault_connection_enabled || var.keyvault_account_id != null
      error_message = "FR-045 — keyvault_connection_enabled=true requires a non-null keyvault_account_id."
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
  target_resource_id         = azapi_resource.this.id
  log_analytics_workspace_id = var.shared_log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# C-018 (Amendment 2026-05-31) — opt-in private endpoint (FR-027). When
# var.private_endpoint_enabled is true the account is reachable only from the
# spoke VNet: the NIC lands in var.private_endpoint_subnet_id, the
# private_service_connection targets the account with the Cognitive Services
# group id "account", and the private_dns_zone_group registers A-records in the
# hub cogsvc/openai/aiservices zones (var.private_dns_zone_ids). The
# project child shares the parent account endpoint and needs no separate PE.
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
    private_connection_resource_id = azapi_resource.this.id
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  lifecycle {
    precondition {
      condition     = var.private_endpoint_subnet_id != null && length(var.private_dns_zone_ids) > 0
      error_message = "C-018 / FR-027 — private_endpoint_enabled=true requires a non-null private_endpoint_subnet_id and a non-empty private_dns_zone_ids list."
    }
  }
}

# C-019 (Amendment 2026-06-01) — opt-in Application Insights for Foundry
# tracing/monitoring (FR-028). When var.application_insights_enabled is true
# the wrapper provisions a WORKSPACE-BASED App Insights anchored at the shared
# hub Log Analytics workspace (so all trace/telemetry data lands in the hub LA
# — no redundant diagnostic setting needed) and attaches it to the account via
# an "AppInsights" connection that all child projects inherit
# (isSharedToAll = true). Both resources resolve to inert (zero-count) defaults
# unless the toggle is set, preserving day-one behaviour.
resource "azurerm_application_insights" "tracing" {
  count               = var.application_insights_enabled ? 1 : 0
  name                = local.appi_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  application_type    = local.config.application_insights_application_type
  # C-051 (Amendment 2026-06-03) — public-access surface (FR-041 §2). Disabled
  # internet ingestion/query when the services stack runs private-by-default
  # (App Insights has no classic PE; AMPLS is the tracked follow-up).
  internet_ingestion_enabled = var.telemetry_internet_access_enabled
  internet_query_enabled     = var.telemetry_internet_access_enabled
  # Workspace-based mode: anchor at the SHARED hub LA (the always-required,
  # already-validated C-014 workspace id) so telemetry routes to the hub LA.
  workspace_id = var.shared_log_analytics_workspace_id
}

# C-019 — Foundry tracing connection. The Foundry portal's Tracing feature
# reads an account/project connection of category "AppInsights" to discover
# where to send/read traces; provisioning the App Insights alone does NOT
# attach it. parent_id is the ACCOUNT so every current/future project inherits
# the connection. The (sensitive) App Insights connection string is supplied
# via sensitive_body so it never appears in plaintext state diff. The fixed
# name "appinsights" satisfies the connection-name RP pattern
# ^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$ (the canonical name's dots/length do not).
resource "azapi_resource" "appinsights_connection" {
  count     = var.application_insights_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
  name      = "appinsights"
  parent_id = azapi_resource.this.id

  body = {
    properties = {
      category      = "AppInsights"
      target        = azurerm_application_insights.tracing[0].id
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_application_insights.tracing[0].id
      }
    }
  }

  sensitive_body = {
    properties = {
      credentials = {
        key = azurerm_application_insights.tracing[0].connection_string
      }
    }
  }

  response_export_values = ["id"]
}

# C-024..C-026 / FR-031 (Amendment 2026-06-02) — Hosted-Agent BYO connections.
# When network injection is on, the Agents capability host (below) needs THREE
# account connections referencing customer-owned Storage, Cosmos DB and AI
# Search. The connection names are fixed/short (C-025) to satisfy the RP
# pattern; category/target/authType follow the Foundry BYO contract. All three
# resolve to zero-count (inert) defaults unless var.network_injection_enabled
# is set, preserving day-one behaviour.
resource "azapi_resource" "agent_storage_connection" {
  count     = local.network_injection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
  name      = local.agent_conn_storage
  parent_id = azapi_resource.this.id

  body = {
    properties = {
      category      = "AzureStorageAccount"
      target        = local.agent_storage_blob_target
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.agent_storage_account_id
      }
    }
  }

  response_export_values = ["id"]
}

resource "azapi_resource" "agent_cosmos_connection" {
  count     = local.network_injection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
  name      = local.agent_conn_cosmos
  parent_id = azapi_resource.this.id

  body = {
    properties = {
      category      = "CosmosDB"
      target        = var.agent_cosmosdb_account_id
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.agent_cosmosdb_account_id
      }
    }
  }

  response_export_values = ["id"]
}

resource "azapi_resource" "agent_search_connection" {
  count     = local.network_injection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
  name      = local.agent_conn_search
  parent_id = azapi_resource.this.id

  body = {
    properties = {
      category      = "CognitiveSearch"
      target        = var.agent_search_service_id
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.agent_search_service_id
      }
    }
  }

  response_export_values = ["id"]
}

# C-026 / FR-031 step 3 (VC-3) — Agents capability host. capabilityHostKind is
# "Agents"; customerSubnet is the dedicated agent subnet; the three connection
# lists reference the connection NAMES created above (depends_on guarantees they
# exist first — VC-3 hard-fails otherwise). storageConnections=Storage,
# threadStorageConnections=Cosmos DB, vectorStoreConnections=AI Search.
resource "azapi_resource" "capability_host" {
  count     = local.network_injection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/capabilityHosts@2025-09-01"
  name      = "agents"
  parent_id = azapi_resource.this.id

  body = {
    properties = {
      capabilityHostKind       = "Agents"
      customerSubnet           = var.agent_subnet_id
      storageConnections       = [local.agent_conn_storage]
      threadStorageConnections = [local.agent_conn_cosmos]
      vectorStoreConnections   = [local.agent_conn_search]
    }
  }

  depends_on = [
    azapi_resource.agent_storage_connection,
    azapi_resource.agent_cosmos_connection,
    azapi_resource.agent_search_connection,
  ]

  response_export_values = ["id"]
}

# C-060 / FR-044 (Amendment 2026-06-04) — userOwnedStorage connection. The
# portal Standard-Agent template attaches the account's own (2nd) storage both
# as `properties.userOwnedStorage` (account body, see locals.tf) AND as an
# AzureStorageAccount account connection named `<account>-userowned`. We mirror
# the connection with a fixed short name `accountstorage` (the canonical name's
# dots/length cannot satisfy the connection-name RP pattern — C-025). The
# `target` MUST be the Blob endpoint URI (the RP rejects a resource ID for
# AzureStorageAccount connections — same rule as the agent storage connection).
# Inert (zero-count) unless var.account_storage_account_id is supplied,
# preserving day-one behaviour.
resource "azapi_resource" "account_storage_connection" {
  count     = local.account_storage_connection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
  name      = "accountstorage"
  parent_id = azapi_resource.this.id

  body = {
    properties = {
      category      = "AzureStorageAccount"
      target        = local.account_storage_blob_target
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.account_storage_account_id
      }
    }
  }

  response_export_values = ["id"]
}

# C-061 / FR-045 (Amendment 2026-06-04) — Key Vault connection on the account.
# Mirrors the portal Standard-Agent template's `<account>-keyvault` connection:
# category=AzureKeyVault, authType=AccountManagedIdentity, isSharedToAll=true so
# child projects inherit it. Fixed short name `keyvault` (C-025). `target` and
# `metadata.ResourceId` are the Key Vault resource id. Inert (zero-count) unless
# var.keyvault_account_id is supplied, preserving day-one behaviour.
resource "azapi_resource" "keyvault_connection" {
  count     = local.keyvault_connection_enabled ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/connections@2025-09-01"
  name      = "keyvault"
  parent_id = azapi_resource.this.id

  # The portal template's runtime authType `AccountManagedIdentity` is a valid
  # Cognitive Services connection auth mode but is missing from azapi's embedded
  # connection schema (which only lists the generic 'ManagedIdentity'); disable
  # schema validation for this one resource so we send the template-exact value.
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "AzureKeyVault"
      target        = var.keyvault_account_id
      authType      = "AccountManagedIdentity"
      isSharedToAll = true
      credentials   = {}
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.keyvault_account_id
        location   = var.location
      }
    }
  }

  response_export_values = ["id"]
}
