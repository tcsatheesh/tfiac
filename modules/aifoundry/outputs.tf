output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azapi_resource.this.id
}

# C-018 (Amendment 2026-05-31) — private endpoint id (null when PE disabled).
output "private_endpoint_id" {
  description = "Azure resource ID of the account private endpoint, or null when private_endpoint_enabled = false (FR-027)."
  value       = one(azurerm_private_endpoint.this[*].id)
}
