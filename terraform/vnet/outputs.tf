output "vnet_id" {
  description = "vnet resource id."
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "vnet canonical name."
  value       = module.network.vnet_name
}

output "vnet_address_space" {
  description = "vnet address space."
  value       = module.network.vnet_address_space
}

output "subnets" {
  description = "Map of role => subnet attributes."
  value       = module.network.subnets
}

output "nsgs" {
  description = "Map of role => NSG attributes."
  value       = module.network.nsgs
}

output "route_table_id" {
  description = "Route table id."
  value       = module.network.route_table_id
}

output "route_table_name" {
  description = "Route table canonical name."
  value       = module.network.route_table_name
}

output "firewall_private_ip" {
  description = "Firewall private IP (hub only; null on spoke)."
  value       = module.network.firewall_private_ip
}

output "firewall_id" {
  description = "Firewall resource id (hub only)."
  value       = module.network.firewall_id
}

output "bastion_id" {
  description = "Bastion resource id (hub only)."
  value       = module.network.bastion_id
}

output "resource_group_name" {
  description = "RG name."
  value       = module.network.resource_group_name
}

output "resource_group_id" {
  description = "RG resource id."
  value       = module.network.resource_group_id
}

output "naming" {
  description = "Engine names map."
  value       = module.network.naming
}

output "peering_ids" {
  description = "Peering resource ids (spoke only)."
  value = (
    var.role == "spoke"
    ? {
      spoke_to_hub = module.peering[0].spoke_to_hub_id
      hub_to_spoke = module.peering[0].hub_to_spoke_id
    }
    : null
  )
}

output "dnslinks_link_ids" {
  description = "Map of {zone_key} => private DNS zone vnet-link resource id (FR-218 visibility)."
  value       = module.dnslinks.link_ids
}

output "dnslinks_count" {
  description = "Count of private DNS zone vnet-links emitted by this stack (FR-218 case a probe)."
  value       = module.dnslinks.link_count
}
