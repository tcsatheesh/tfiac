###############################################################################
# modules/loganalytics/outputs.tf
###############################################################################

output "workspace_id" {
  description = "Azure resource ID of the Log Analytics Workspace."
  value       = module.workspace.resource_id
}

output "workspace_name" {
  description = "Workspace canonical name (e.g. log-hub-prd-sdc-001)."
  value       = local.ws_canonical_name
}

output "resource_group_name" {
  description = "Per-stack resource group name."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Resource group Azure ID."
  value       = azurerm_resource_group.this.id
}
