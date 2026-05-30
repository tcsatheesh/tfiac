output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_user_assigned_identity.this.id
}
