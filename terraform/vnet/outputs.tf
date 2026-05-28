###############################################################################
# terraform/vnet/outputs.tf
###############################################################################

output "resource_group_name" { value = module.network.resource_group_name }
output "vnet_id" { value = module.network.vnet_id }
output "vnet_name" { value = module.network.vnet_name }
output "subnet_ids" { value = module.network.subnet_ids }
output "subnet_names" { value = module.network.subnet_names }

# Hub-only outputs (null when role=spoke).
output "firewall_private_ip" {
  value = local.is_hub ? module.firewall[0].private_ip : null
}
output "firewall_id" {
  value = local.is_hub ? module.firewall[0].firewall_id : null
}
output "bastion_id" {
  value = local.is_hub ? module.bastion[0].bastion_id : null
}
output "peered_spoke_vnet_names" {
  description = "(role=hub) Spoke vnet names this hub has registered hub_to_spoke peers for. Consumed by spoke's check.hub_peering_registered."
  value       = local.is_hub ? [for k, v in var.spoke_peerings : v.remote_vnet_name] : []
}

# Spoke-only output.
output "peering_enabled" {
  value = local.is_spoke ? (local.hub_vnet_id != "") : null
}

output "role" { value = var.role }
