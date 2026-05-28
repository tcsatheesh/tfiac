###############################################################################
# modules/loganalytics/outputs.tf
###############################################################################

output "workspace_id" {
  description = "Azure resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Workspace canonical name (e.g. log-hub-prd-sdc-001)."
  value       = azurerm_log_analytics_workspace.this.name
}

output "resource_group_name" {
  description = "Per-stack resource group name."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Resource group Azure ID."
  value       = azurerm_resource_group.this.id
}

output "workspace_primary_shared_key" {
  description = "Primary shared key for agent enrollment. Sensitive."
  value       = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive   = true
}
