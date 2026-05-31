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
