###############################################################################
# terraform/log-npd/outputs.tf
###############################################################################

output "workspace_id" {
  description = "Log Analytics Workspace resource ID."
  value       = module.log.workspace_id
}

output "workspace_name" {
  description = "Workspace canonical name."
  value       = module.log.workspace_name
}

output "resource_group_name" {
  description = "Per-stack resource group name."
  value       = module.log.resource_group_name
}
