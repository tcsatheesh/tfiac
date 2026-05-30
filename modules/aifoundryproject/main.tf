# AI Foundry project: hand-rolled via azapi until a stable AVM module ships.
# A Project is a Microsoft.MachineLearningServices/workspaces with kind=Project
# whose properties.hubResourceId points at the parent Foundry Hub. Storage and
# key-vault are inherited from the Hub; we do NOT re-declare them here.
data "azurerm_subscription" "current" {}

resource "azapi_resource" "this" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-10-01"
  name      = var.canonical_name
  location  = var.location
  parent_id = "${data.azurerm_subscription.current.id}/resourceGroups/${var.resource_group_name}"
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "Project"
    sku  = { name = "Basic" }
    properties = {
      friendlyName        = var.canonical_name
      hubResourceId       = var.hub_resource_id
      publicNetworkAccess = local.config.public_network_access
    }
  }

  response_export_values = ["id", "properties.discoveryUrl"]
}

# C-014 (Amendment 2026-05-31) — default diagnostic settings to shared hub LA.
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
