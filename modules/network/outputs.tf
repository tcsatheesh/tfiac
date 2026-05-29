###############################################################################
# modules/network/outputs.tf
###############################################################################

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "vnet_id" {
  value = module.vnet.resource_id
}

output "vnet_name" {
  # Use the canonical name (not module.vnet.resource.name) to avoid
  # pulling any sensitive-output attributes from the AVM resource object.
  value = local.vnet_name
}

output "subnet_ids" {
  description = "Map of role => subnet ID."
  value       = { for r, s in module.vnet.subnets : r => s.resource_id }
}

output "subnet_names" {
  description = "Map of role => canonical/literal subnet name."
  value       = local.subnet_name_for
}

output "nsg_ids" {
  description = "Map of role => NSG ID (only for roles with add_nsg=true)."
  value       = { for r, n in module.nsg : r => n.resource_id }
}

output "route_table_id" {
  description = "Route table ID (null when no route-attached subnet roles requested)."
  value       = length(module.route_table) > 0 ? module.route_table[0].resource_id : null
}

output "subnet_role_catalogue" {
  description = "Snapshot of supported subnet roles (for documentation / introspection)."
  value       = keys(local.subnet_roles)
}
