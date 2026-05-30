output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_application_insights.this.id
}
