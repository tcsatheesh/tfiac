output "resource_id" {
  description = "Azure resource ID of the Container Apps Managed Environment."
  value       = azurerm_container_app_environment.this.id
}

output "default_domain" {
  description = "The internal default domain of the environment (also the private DNS zone name)."
  value       = azurerm_container_app_environment.this.default_domain
}

output "static_ip_address" {
  description = "The internal static IP of the environment ingress."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "private_dns_zone_id" {
  description = "Azure resource ID of the private DNS zone created for the default domain."
  value       = azurerm_private_dns_zone.default_domain.id
}
