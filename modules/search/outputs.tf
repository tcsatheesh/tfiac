output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_search_service.this.id
}

output "private_endpoint_id" {
  description = "C-039 / FR-035: resource ID of the private endpoint when private_endpoint_enabled = true; null otherwise."
  value       = one(azurerm_private_endpoint.this[*].id)
}
