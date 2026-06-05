# Public output surface.

output "vm_id" {
  description = "Azure resource id of the Windows jump-box VM."
  value       = module.vm.resource_id
}

output "vm_name" {
  description = "Engine-emitted VM canonical name."
  value       = local.vm_canonical_name
}

output "vm_private_ip" {
  description = "Primary private IP of the jump-box VM."
  value       = try(module.vm.virtual_machine_azurerm.private_ip_address, null)
}

output "resource_group_name" {
  description = "Name of the (existing) resource group the VM lives in."
  value       = data.azurerm_resource_group.existing.name
}

output "principal_id" {
  description = "System-assigned managed identity principal id."
  value       = try(module.vm.system_assigned_mi_principal_id, null)
}

output "admin_password_secret_id" {
  description = "Key Vault secret id holding the generated local admin password (the id, not the value)."
  value       = azurerm_key_vault_secret.admin_password.id
}

output "nic_name" {
  description = "Derived NIC name."
  value       = local.nic_name
}

output "os_disk_name" {
  description = "Derived OS disk name."
  value       = local.os_disk_name
}

output "naming" {
  description = "Engine names passthrough for audit."
  value       = module.naming.names
}
