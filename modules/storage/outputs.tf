output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_storage_account.this.id
}
