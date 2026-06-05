output "vm_id" {
  description = "Azure resource id of the Windows jump-box VM."
  value       = module.winvm.vm_id
}

output "vm_name" {
  description = "Engine-emitted VM canonical name."
  value       = module.winvm.vm_name
}

output "vm_private_ip" {
  description = "Primary private IP of the jump-box VM."
  value       = module.winvm.vm_private_ip
}

output "resource_group_name" {
  description = "Name of the (existing) resource group the VM lives in."
  value       = module.winvm.resource_group_name
}

output "principal_id" {
  description = "System-assigned managed identity principal id."
  value       = module.winvm.principal_id
}

output "admin_password_secret_id" {
  description = "Key Vault secret id holding the generated local admin password (id, not value)."
  value       = module.winvm.admin_password_secret_id
}

output "naming" {
  description = "Engine names passthrough for audit."
  value       = module.winvm.naming
}
