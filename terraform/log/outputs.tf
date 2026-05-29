# T015 - 1:1 re-export of the wrapper-module output surface (contracts/log-stack.md).
# `sensitive = true` is restated explicitly at the root layer as defence-in-depth
# (LOG-INV-10, research D8): a future refactor that mistakenly drops the
# sensitive flag on the module output would still be caught here.

output "workspace_id" {
  description = "Log Analytics workspace customer ID."
  value       = module.loganalytics.workspace_id
  sensitive   = true
}

output "workspace_resource_id" {
  description = "Azure resource ID of the workspace."
  value       = module.loganalytics.workspace_resource_id
}

output "workspace_name" {
  description = "Engine-emitted workspace Azure resource name."
  value       = module.loganalytics.workspace_name
}

output "resource_group_name" {
  description = "Engine-emitted RG name."
  value       = module.loganalytics.resource_group_name
}

output "resource_group_id" {
  description = "Engine-emitted RG Azure resource id."
  value       = module.loganalytics.resource_group_id
}

output "primary_shared_key" {
  description = "Workspace primary shared key (sensitive)."
  value       = module.loganalytics.primary_shared_key
  sensitive   = true
}

output "naming" {
  description = "Passthrough of module.naming.names for audit."
  value       = module.loganalytics.naming
}
