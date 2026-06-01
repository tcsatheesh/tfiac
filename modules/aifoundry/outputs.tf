output "resource_id" {
  description = "Azure resource ID of the emitted resource."
  value       = azapi_resource.this.id
}

# C-018 (Amendment 2026-05-31) — private endpoint id (null when PE disabled).
output "private_endpoint_id" {
  description = "Azure resource ID of the account private endpoint, or null when private_endpoint_enabled = false (FR-027)."
  value       = one(azurerm_private_endpoint.this[*].id)
}

# C-019 (Amendment 2026-06-01) — Foundry-tracing App Insights ids (null when
# application_insights_enabled = false).
output "application_insights_id" {
  description = "Azure resource ID of the embedded Foundry-tracing Application Insights, or null when application_insights_enabled = false (FR-028)."
  value       = one(azurerm_application_insights.tracing[*].id)
}

output "application_insights_connection_id" {
  description = "Azure resource ID of the account-level AppInsights tracing connection, or null when application_insights_enabled = false (FR-028)."
  value       = one(azapi_resource.appinsights_connection[*].id)
}
