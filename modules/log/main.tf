resource "azurerm_resource_group" "avmrg" {
  name     = var.log.resource_group_name
  location = var.log.location
}

module "log_analytics_workspace" {
  source                                             = "Azure/avm-res-operationalinsights-workspace/azurerm"
  location                                           = var.log.location
  resource_group_name                                = azurerm_resource_group.avmrg.name
  name                                               = var.log.workspace_name
  log_analytics_workspace_retention_in_days          = 90
  log_analytics_workspace_sku                        = "PerGB2018"
  log_analytics_workspace_internet_ingestion_enabled = true
  log_analytics_workspace_internet_query_enabled     = true
  enable_telemetry                                   = false
}