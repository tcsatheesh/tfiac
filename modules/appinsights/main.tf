resource "azurerm_application_insights" "this" {
  name                       = var.services.app_insights.name
  location                   = var.services.location
  resource_group_name        = var.services.resource_group_name
  workspace_id               = data.azurerm_log_analytics_workspace.this.id
  application_type           = "web"
  internet_ingestion_enabled = var.services.app_insights.internet_ingestion_enabled
  internet_query_enabled     = var.services.app_insights.internet_query_enabled
}

output "instrumentation_key" {
  value = azurerm_application_insights.this.instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.this.app_id
}

output "app_insights_id" {
  value = azurerm_application_insights.this.id
}

output "connection_string" {
  value = azurerm_application_insights.this.connection_string
}