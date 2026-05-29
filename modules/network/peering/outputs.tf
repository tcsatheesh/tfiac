output "spoke_to_hub_id" {
  description = "Peering resource id (spoke side)."
  value       = azurerm_virtual_network_peering.spoke_to_hub.id
}

output "hub_to_spoke_id" {
  description = "Peering resource id (hub side)."
  value       = azurerm_virtual_network_peering.hub_to_spoke.id
}
