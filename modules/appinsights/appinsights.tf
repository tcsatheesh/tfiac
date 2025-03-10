variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}


provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = var.log.subscription_id
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

resource "azurerm_application_insights" "this" {
  name                = var.services.app_insights_name
  location            = var.services.location
  resource_group_name = var.services.resource_group_name
  workspace_id        = data.azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  internet_ingestion_enabled = var.services.internet_ingestion_enabled == true ? true : false
  internet_query_enabled = var.services.internet_query_enabled == true ? true : false
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