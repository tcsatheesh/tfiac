output "link_ids" {
  description = "Map of {catalogue_key|custom_fqdn} => Azure resource id of the vnet-link (FR-218 visibility, downstream assertion target)."
  value       = { for k, l in azurerm_private_dns_zone_virtual_network_link.this : k => l.id }
}

output "link_count" {
  description = "Number of vnet-links emitted by this submodule call (FR-218 case a / C16.8 a probe)."
  value       = length(azurerm_private_dns_zone_virtual_network_link.this)
}
