output "vnet_id" {
  description = "Azure resource id of the vnet (FR-206 consumer key)."
  value       = module.vnet.resource_id
}

output "vnet_name" {
  description = "Engine-emitted vnet canonical name."
  value       = local.vnet_canonical_name
}

output "vnet_tags" {
  description = "Tags applied to the vnet by the naming engine. Re-exported so cross-stack consumers (e.g. modules/dnslinks/) tag derived resources consistently with their consuming vnet (FR-219, C16.9, plan §5)."
  value       = module.naming.names[local.vnet_canonical_name].tags
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
  description = "Hub firewall private IP (null on spoke or when the hub firewall is disabled via enable_hub_firewall)."
  value       = length(module.firewall) > 0 ? module.firewall[0].private_ip : null
}

output "firewall_id" {
  description = "Hub firewall resource id (null on spoke or when the hub firewall is disabled)."
  value       = length(module.firewall) > 0 ? module.firewall[0].resource_id : null
}

output "bastion_id" {
  description = "Hub bastion resource id (null on spoke)."
  value       = var.role == "hub" ? module.bastion[0].resource_id : null
}

output "firewall_pip_ip_tags" {
  description = "First-party ip_tags applied to the hub firewall PIPs (null on spoke or when the hub firewall is disabled). FR-223 / C16.14; exposed for plan-time tests."
  value       = length(module.firewall) > 0 ? module.firewall[0].pip_ip_tags : null
}

output "bastion_pip_ip_tags" {
  description = "First-party ip_tags applied to the hub bastion PIP (null on spoke). FR-223 / C16.14; exposed for plan-time tests."
  value       = var.role == "hub" ? module.bastion[0].pip_ip_tags : null
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

output "subnet_service_endpoints" {
  description = "Map of role => list({service, locations}) actually passed to the subnet AVM module. Exposed so plan-time tests can assert FR-225 regional expansion is applied (e.g. Microsoft.Storage in swedencentral => [\"swedencentral\",\"swedensouth\"])."
  value = {
    for r in local.active_roles : r => [
      for ep in local.role_catalogue[r].service_endpoints : {
        service   = ep
        locations = ep == "Microsoft.Storage" ? lookup(local.storage_se_locations, local.region_full, ["*"]) : ["*"]
      }
    ]
  }
}

output "subnet_delegations" {
  description = "Map of role => list(delegation service name) actually passed to the subnet AVM module. Exposed so plan-time tests can assert delegation wiring (e.g. the FR-226 `agents` role delegates Microsoft.App/environments)."
  value = {
    for r in local.active_roles : r => local.role_catalogue[r].delegation
  }
}

output "subnet_route_table_attached" {
  description = "Map of role => bool indicating whether the subnet EFFECTIVELY attaches the shared route table (needs_route_table AND route_table_active). Exposed so plan-time tests can assert FR-226 (`agents`/`container-apps` never attach) and FR-228 (no subnet attaches when no default route exists)."
  value = {
    for r in local.active_roles : r => local.role_catalogue[r].needs_route_table && local.route_table_active
  }
}

output "route_table_active" {
  description = "Whether the shared route table carries a real 0.0.0.0/0 default route worth attaching to workload subnets (FR-228). Hub: enable_hub_firewall && enable_hub_default_route. Spoke: hub_firewall_private_ip != null."
  value       = local.route_table_active
}

output "nat_gateway_id" {
  description = "Hub NAT gateway resource id (FR-229). Null on spoke or when enable_hub_nat_gateway is false."
  value       = length(module.nat) > 0 ? module.nat[0].resource_id : null
}

output "subnet_nat_attached" {
  description = "Map of role => bool indicating whether the subnet EFFECTIVELY associates the hub NAT gateway (FR-229): role=hub AND enable_hub_nat_gateway AND needs_route_table. Exposed for plan-time tests."
  value = {
    for r in local.active_roles : r => (
      var.role == "hub" && var.enable_hub_nat_gateway && local.role_catalogue[r].needs_route_table
    )
  }
}
