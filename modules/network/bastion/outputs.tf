output "resource_id" {
  description = "Bastion resource id."
  value       = module.bastion.resource_id
}

output "name" {
  description = "Bastion name."
  value       = module.bastion.name
}

output "public_ip_id" {
  description = "Resource id of the externally-managed bastion data-plane PIP (FR-224)."
  value       = module.pip.public_ip_id
}

output "pip_ip_tags" {
  description = "First-party ip_tags applied to the bastion PIP (FR-223 / C16.14). Exposed for plan-time tests."
  value       = local.first_party_pip_ip_tags
}
