output "resource_group_name" { value = module.network.resource_group_name }
output "vnet_id" { value = module.network.vnet_id }
output "vnet_name" { value = module.network.vnet_name }
output "subnet_ids" { value = module.network.subnet_ids }
output "subnet_names" { value = module.network.subnet_names }
output "peering_enabled" { value = local.enable_peering }
