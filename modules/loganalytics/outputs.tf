# T011/T027 - public output surface (contracts/log-stack.md).
# Output names, types, and sensitivity are the published consumer contract;
# changing any of them is a breaking change per semver.

output "workspace_id" {
  description = "Log Analytics workspace customer ID (GUID). Used by consumers wiring diagnostic settings via SDK/CLI (FR-106)."
  value       = module.workspace.resource.workspace_id
  # `module.workspace.resource` is marked sensitive by the AVM module; mark this
  # explicitly sensitive to allow the projection.
  sensitive = true
}

output "workspace_resource_id" {
  description = "Azure resource ID of the workspace. Used by consumers wiring azurerm_monitor_diagnostic_setting (FR-106)."
  value       = module.workspace.resource_id
}

output "workspace_name" {
  description = "Engine-emitted workspace Azure resource name (LOG-INV-11)."
  # Plan-time-known because we constructed it locally from var.input; the AVM
  # module's `name` output is computed by azapi at apply time and is therefore
  # not safe to reference from snapshot tests.
  value = local.workspace_canonical_name
}

output "resource_group_name" {
  description = "Engine-emitted RG name carrying the workspace (FR-106)."
  value       = local.rg_canonical_name
}

output "resource_group_id" {
  description = "Engine-emitted RG Azure resource id (FR-106)."
  value       = module.rg.resource_id
}

output "primary_shared_key" {
  description = "Workspace primary shared key. Sensitive - never log; never echo to CI (LOG-INV-10, FR-106)."
  value       = module.workspace.resource.primary_shared_key
  sensitive   = true
}

output "naming" {
  description = "Passthrough of module.naming.names for audit (FR-106)."
  value       = module.naming.names
}
