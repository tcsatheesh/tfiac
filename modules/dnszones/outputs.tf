# Public output surface (contracts/dns-stack.md). Output keys for zone_ids /
# zone_names are catalogue keys (for catalogue entries) and FQDNs (for custom
# entries), per FR-024.

output "zone_ids" {
  description = "Map of {catalogue_key|custom_fqdn} => Azure private_dns_zone resource id (FR-020)."
  value       = { for k, m in module.zone : k => m.resource_id }

  # DNS-INV-10: keys(zone_ids) == keys(zone_names) (parallel maps).
  precondition {
    condition     = sort(keys(local.effective_zones)) == sort(keys({ for k, m in module.zone : k => m.resource_id }))
    error_message = "DNS-INV-10: zone_ids keys diverge from the effective_zone set; this is a bug in the wrapper module."
  }
}

output "zone_names" {
  description = "Map of {catalogue_key|custom_fqdn} => zone FQDN (FR-021)."
  value       = { for k, v in local.effective_zones : k => v.fqdn }
}

output "resource_group_name" {
  description = "Engine-emitted RG name carrying every zone in this stack (FR-022)."
  # Use the locally-derived canonical name so the value is plan-time known
  # (the AVM RG module's `name` output is computed by azapi at apply time).
  # local.rg_canonical_name is constructed from the same `local.engine_input`
  # values the engine hashes into the actual RG, so the two are identical.
  value = local.rg_canonical_name
}

output "resource_group_id" {
  description = "Engine-emitted RG resource id (FR-022)."
  value       = module.rg.resource_id
}

output "naming" {
  description = "Passthrough of module.naming.names for audit (FR-023)."
  value       = module.naming.names
}
