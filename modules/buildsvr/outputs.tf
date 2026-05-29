# Public output surface.

output "vm_id" {
  description = "Azure resource id of the build server VM."
  value       = module.vm.resource_id
}

output "vm_name" {
  description = "Engine-emitted VM canonical name."
  value       = local.vm_canonical_name
}

output "vm_private_ip" {
  description = "Primary private IP of the build server VM."
  value       = try(module.vm.virtual_machine_azurerm.private_ip_address, null)
}

output "resource_group_name" {
  description = "Engine-emitted RG name."
  value       = local.rg_canonical_name
}

output "resource_group_id" {
  description = "Engine-emitted RG resource id."
  value       = module.rg.resource_id
}

output "principal_id" {
  description = "System-assigned managed identity principal id."
  value       = try(module.vm.system_assigned_mi_principal_id, null)
}

output "runner_status" {
  description = "Informational: \"registered\" when github_runner_token is non-empty at apply time, otherwise \"unregistered\". Marked sensitive because it is derived from the sensitive github_runner_token (Terraform's transitive-sensitivity tracking)."
  value       = local.runner_status
  sensitive   = true
}

output "nic_name" {
  description = "Derived NIC name."
  value       = local.nic_name
}

output "data_disk_name" {
  description = "Derived data disk name."
  value       = local.data_disk_name
}

output "os_disk_name" {
  description = "Derived OS disk name."
  value       = local.os_disk_name
}

output "naming" {
  description = "Engine names passthrough for audit."
  value       = module.naming.names
}
