###############################################################################
# terraform/dns/outputs.tf  (feature 002 — stable consumer contract)
#
# See specs/002-private-dns-zones/contracts/output-schema.md for the
# breaking-change rules.
###############################################################################

output "zone_ids" {
  description = "Map of catalogue-key-or-FQDN → Azure resource ID for every created zone."
  value       = module.dnszones.zone_ids
}

output "zone_names" {
  description = "Map of catalogue-key-or-FQDN → FQDN."
  value       = module.dnszones.zone_names
}

output "resource_group_name" {
  description = "Engine-emitted per-stack RG name."
  value       = module.dnszones.resource_group_name
}

output "resource_group_id" {
  description = "Azure resource ID of the per-stack RG."
  value       = module.dnszones.resource_group_id
}

output "naming" {
  description = "Full engine record set (passthrough of module.naming.names). Custom zones are NOT represented here (OQ-001 → B)."
  value       = module.naming.names
}
