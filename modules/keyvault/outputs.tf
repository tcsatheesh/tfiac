output "resource_id" {
  description = "Azure resource ID of the key vault."
  value       = azurerm_key_vault.this.id
}
