output "resource_id" {
  description = "Azure resource ID of the Data Factory."
  value       = azurerm_data_factory.this.id
}

output "identity_principal_id" {
  description = "Object id of the ADF system-assigned managed identity."
  value       = azurerm_data_factory.this.identity[0].principal_id
}

output "private_endpoint_ids" {
  description = "Resource IDs of the ADF inbound private endpoints (dataFactory + portal)."
  value       = [azurerm_private_endpoint.data.id, azurerm_private_endpoint.portal.id]
}
