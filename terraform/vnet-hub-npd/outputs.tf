output "resource_group_name" { value = module.network.resource_group_name }
output "vnet_id" { value = module.network.vnet_id }
output "vnet_name" { value = module.network.vnet_name }
output "subnet_ids" { value = module.network.subnet_ids }
output "subnet_names" { value = module.network.subnet_names }
output "firewall_private_ip" { value = module.firewall.private_ip }
output "firewall_id" { value = module.firewall.firewall_id }
output "bastion_id" { value = module.bastion.bastion_id }
