output "vnet_id" {
  description = "Azure resource id of the vnet (FR-206 consumer key)."
  value       = module.vnet.resource_id
}

output "vnet_name" {
  description = "Engine-emitted vnet canonical name."
  value       = local.vnet_canonical_name
}

output "vnet_address_space" {
  description = "Address space as deployed."
  value       = var.address_space
}

output "subnets" {
  description = "Map of role => { id, name, address_prefix }."
  value = {
    for r in local.active_roles : r => {
      id             = module.vnet.subnets[local.role_catalogue[r].abbr3].resource_id
      name           = local.subnet_canonical_names[r]
      address_prefix = var.subnets[r]
    }
  }
}

output "nsgs" {
  description = "Map of role => { id, name }."
  value = {
    for r in local.nsg_roles : r => {
      id   = module.nsg[r].resource_id
      name = local.nsg_canonical_names[r]
    }
  }
}

output "route_table_id" {
  description = "Azure resource id of the route table."
  value       = module.rt.resource_id
}

output "route_table_name" {
  description = "Engine-emitted route table canonical name."
  value       = local.rt_canonical_name
}

output "firewall_private_ip" {
  description = "Hub firewall private IP (null on spoke)."
  value       = var.role == "hub" ? module.firewall[0].private_ip : null
}

output "firewall_id" {
  description = "Hub firewall resource id (null on spoke)."
  value       = var.role == "hub" ? module.firewall[0].resource_id : null
}

output "bastion_id" {
  description = "Hub bastion resource id (null on spoke)."
  value       = var.role == "hub" ? module.bastion[0].resource_id : null
}

output "resource_group_name" {
  description = "Engine-emitted RG name."
  value       = local.rg_canonical_name
}

output "resource_group_id" {
  description = "Resource id of the wrapping RG."
  value       = module.rg.resource_id
}

output "naming" {
  description = "Engine names map (for callers that need the full set)."
  value       = module.naming.names
}
