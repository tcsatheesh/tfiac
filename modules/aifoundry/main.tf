# AI Foundry account: hand-rolled via azapi until a stable AVM module ships.
# C-017 (Amendment 2026-05-30) — rebased from the legacy
# Microsoft.MachineLearningServices/workspaces (kind=Hub) RP onto
# Microsoft.CognitiveServices/accounts (kind=AIServices,
# allowProjectManagement=true) to match the admin-1364-resource shape.
# Foundry accounts manage their own underlying storage and secrets; no
# sibling Key Vault / Storage Account inputs are required.
data "azurerm_subscription" "current" {}

resource "azapi_resource" "this" {
  type      = "Microsoft.CognitiveServices/accounts@2025-09-01"
  name      = var.canonical_name
  location  = var.location
  parent_id = "${data.azurerm_subscription.current.id}/resourceGroups/${var.resource_group_name}"
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku  = { name = "S0" }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = var.canonical_name
      publicNetworkAccess    = local.config.public_network_access
    }
  }

  response_export_values = ["id", "properties.endpoints"]
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
