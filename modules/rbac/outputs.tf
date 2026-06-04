output "role_assignment_ids" {
  description = "Map of caller-key => Azure role assignment resource id (control-plane)."
  value       = { for k, r in azurerm_role_assignment.this : k => r.id }
}

output "cosmos_sql_role_assignment_ids" {
  description = "Map of caller-key => Cosmos DB SQL role assignment resource id (data-plane)."
  value       = { for k, r in azapi_resource.cosmos_sql : k => r.id }
}
