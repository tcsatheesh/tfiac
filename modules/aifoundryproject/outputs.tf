output "resource_id" {
  description = "Azure resource ID of the emitted Foundry Project workspace."
  value       = azapi_resource.this.id
}
