output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_linux_function_app.this.id
}
