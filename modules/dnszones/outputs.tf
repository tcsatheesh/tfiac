# modules/dnszones/outputs.tf
# Stable output contract per specs/002-private-dns-zones/contracts/output-schema.md.

output "zone_ids" {
  description = "Map of catalogue-key-or-FQDN → Azure resource ID for every created zone."
  value       = { for k, m in module.zone : k => m.resource_id }
}

output "zone_names" {
  description = "Map of catalogue-key-or-FQDN → FQDN for every created zone."
  value       = local.zone_set
}

output "resource_group_name" {
  description = "Engine-emitted per-stack RG name."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Azure resource ID of the per-stack RG."
  value       = azurerm_resource_group.this.id
}

output "catalogue_keys" {
  description = "Sorted list of catalogue keys (strings only)."
  value       = sort(keys(local.catalogue))
}

output "catalogue_fqdns" {
  description = "Sorted list of catalogue FQDNs (diagnostics-only)."
  value       = sort(values(local.catalogue))
}
