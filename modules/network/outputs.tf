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
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of role => subnet ID."
  value       = { for r, s in azurerm_subnet.this : r => s.id }
}

output "subnet_names" {
  description = "Map of role => canonical/literal subnet name."
  value       = local.subnet_name_for
}

output "nsg_ids" {
  description = "Map of role => NSG ID (only for roles with add_nsg=true)."
  value       = { for r, n in azurerm_network_security_group.this : r => n.id }
}

output "route_table_id" {
  description = "Route table ID (null when no route-attached subnet roles requested)."
  value       = length(azurerm_route_table.this) > 0 ? azurerm_route_table.this[0].id : null
}

output "subnet_role_catalogue" {
  description = "Snapshot of supported subnet roles (for documentation / introspection)."
  value       = keys(local.subnet_roles)
}
