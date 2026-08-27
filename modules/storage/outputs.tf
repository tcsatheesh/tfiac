output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob service endpoint (https://<name>.blob.core.windows.net/)."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "private_endpoint_id" {
  description = "C-035 / FR-034: resource ID of the private endpoint, or null when private_endpoint_enabled = false."
  value       = one(azurerm_private_endpoint.this[*].id)
}
