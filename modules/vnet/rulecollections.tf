module "denyall" {
  source             = "./rulecollection/denyall"
  firewall_policy_id = module.fwpolicy[0].resource_id
}


module "azuread" {
  source = "./rulecollection/azuread"
  source_ip_groups = [for _key in var.firewall.rulecollections.azuread :
    azurerm_ip_group.this[_key].id
  ]
  firewall_policy_id = module.fwpolicy[0].resource_id
}

