output "resource_group_name" { value = module.network.resource_group_name }
output "vnet_id" { value = module.network.vnet_id }
output "vnet_name" { value = module.network.vnet_name }
output "subnet_ids" { value = module.network.subnet_ids }
output "subnet_names" { value = module.network.subnet_names }
output "firewall_private_ip" { value = module.firewall.private_ip }
output "firewall_id" { value = module.firewall.firewall_id }
output "bastion_id" { value = module.bastion.bastion_id }

output "peered_spoke_vnet_names" {
  description = "Names of spoke vnets the hub has a hub_to_spoke peer for. Consumed by each spoke's check.hub_peering_registered."
  value       = [for k, v in var.spoke_peerings : v.remote_vnet_name]
}
