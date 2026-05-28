# modules/dnszones/outputs.tf
# Stable output contract per specs/002-private-dns-zones/contracts/output-schema.md.

output "zone_ids" {
  description = "Map of catalogue-key-or-FQDN → Azure resource ID for every created zone."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}

output "zone_names" {
  description = "Map of catalogue-key-or-FQDN → FQDN for every created zone."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.name }
}

output "resource_group_name" {
  description = "Engine-emitted per-stack RG name (e.g. rg-hub-prd-<region_code>-001)."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Azure resource ID of the per-stack RG."
  value       = azurerm_resource_group.this.id
}

output "catalogue_keys" {
  description = "Sorted list of catalogue keys (strings only). The root stack consumes this to size the engine's services[].count. FQDN values stay internal per contracts/output-schema.md."
  value       = sort(keys(local.catalogue))
}

output "catalogue_fqdns" {
  description = "Sorted list of catalogue FQDNs. Exposed strictly to enable root-stack check {} blocks that mirror the module preconditions — Terraform 1.9 expect_failures cannot reference module-scope resources, so the catalogue-membership and shadowing assertions are duplicated as root checks for testability. Module preconditions remain the authoritative hard-fail (they fire first); the root checks are diagnostics-only."
  value       = sort(values(local.catalogue))
}
