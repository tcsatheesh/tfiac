output "resource_id" {
  description = "Azure resource ID of the SQL logical server."
  value       = azurerm_mssql_server.this.id
}

output "server_name" {
  description = "SQL logical server name."
  value       = azurerm_mssql_server.this.name
}

output "server_fqdn" {
  description = "Fully-qualified domain name of the SQL server (privatelink-resolved from inside the VNet)."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_id" {
  description = "Azure resource ID of the SQL database."
  value       = azurerm_mssql_database.this.id
}

output "database_name" {
  description = "SQL database name."
  value       = azurerm_mssql_database.this.name
}

output "private_endpoint_id" {
  description = "Azure resource ID of the SQL private endpoint (always provisioned)."
  value       = azurerm_private_endpoint.this.id
}
