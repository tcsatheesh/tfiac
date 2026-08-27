output "resource_id" {
  description = "Azure resource ID of the key vault."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key vault name."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "Key vault data-plane URI (https://<name>.vault.azure.net/)."
  value       = azurerm_key_vault.this.vault_uri
}
