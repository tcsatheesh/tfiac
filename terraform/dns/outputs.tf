# Root-stack outputs: 1:1 re-export of the wrapper module's surface
# (contracts/dns-stack.md).

output "zone_ids" {
  description = "Map of {catalogue_key|custom_fqdn} => private DNS zone resource id (FR-020)."
  value       = module.dnszones.zone_ids
}

output "zone_names" {
  description = "Map of {catalogue_key|custom_fqdn} => zone FQDN (FR-021)."
  value       = module.dnszones.zone_names
}

output "resource_group_name" {
  description = "RG name carrying every zone (FR-022)."
  value       = module.dnszones.resource_group_name
}

output "resource_group_id" {
  description = "RG resource id (FR-022)."
  value       = module.dnszones.resource_group_id
}

output "naming" {
  description = "Passthrough of module.naming.names (FR-023)."
  value       = module.dnszones.naming
}
