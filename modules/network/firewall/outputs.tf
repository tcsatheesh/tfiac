output "resource_id" {
  description = "Firewall resource id."
  value       = module.firewall.resource_id
}

output "private_ip" {
  description = "Firewall data-plane private IP (consumed by spokes for default route)."
  value       = try(module.firewall.resource.ip_configuration[0].private_ip_address, null)
}

output "policy_id" {
  description = "Empty Standard firewall policy id."
  value       = azurerm_firewall_policy.this.id
}

output "pip_ip_tags" {
  description = "First-party ip_tags applied to both firewall PIPs (FR-223 / C16.14). Exposed for plan-time tests."
  value       = local.first_party_pip_ip_tags
}
