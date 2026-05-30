output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azurerm_logic_app_workflow.this.id
}
