resource "azurerm_application_insights" "this" {
  name                       = var.services.app_insights.name
  location                   = var.services.location
  resource_group_name        = var.services.resource_group_name
  workspace_id               = data.azurerm_log_analytics_workspace.this.id
  application_type           = "web"
  internet_ingestion_enabled = var.services.app_insights.internet_ingestion_enabled
  internet_query_enabled     = var.services.app_insights.internet_query_enabled
}
