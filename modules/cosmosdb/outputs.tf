output "resource_id" {
  description = "Azure resource ID of the emitted Cosmos DB account."
  value       = azurerm_cosmosdb_account.this.id
}

output "private_endpoint_id" {
  description = "Azure resource ID of the Cosmos DB private endpoint (always provisioned; FR-032)."
  value       = azurerm_private_endpoint.this.id
}
