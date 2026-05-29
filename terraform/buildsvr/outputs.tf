output "vm_id" {
  description = "Build server VM resource id."
  value       = module.buildsvr.vm_id
}

output "vm_name" {
  description = "Build server VM canonical name."
  value       = module.buildsvr.vm_name
}

output "vm_private_ip" {
  description = "Primary private IP."
  value       = module.buildsvr.vm_private_ip
}

output "resource_group_name" {
  description = "Build server RG canonical name."
  value       = module.buildsvr.resource_group_name
}

output "resource_group_id" {
  description = "Build server RG resource id."
  value       = module.buildsvr.resource_group_id
}

output "principal_id" {
  description = "System-assigned MI principal id."
  value       = module.buildsvr.principal_id
}

output "runner_status" {
  description = "registered | unregistered (informational). Sensitive because derived from github_runner_token."
  value       = module.buildsvr.runner_status
  sensitive   = true
}

output "naming" {
  description = "Engine names map."
  value       = module.buildsvr.naming
}
