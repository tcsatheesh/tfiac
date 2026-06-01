output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_container_registry.this.id
}

output "private_endpoint_id" {
  description = "Azure resource ID of the registry private endpoint, or null when private_endpoint_enabled = false (FR-029)."
  value       = one(azurerm_private_endpoint.this[*].id)
}
