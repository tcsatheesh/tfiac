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

module "aml" {
  source = "./rulecollection/aml"
  source_ip_groups = [for _key in var.firewall.rulecollections.aml :
    azurerm_ip_group.this[_key].id
  ]
  firewall_policy_id = module.fwpolicy[0].resource_id
}

module "buildsvr" {
  source = "./rulecollection/buildsvr"
  source_ip_groups = [for _key in var.firewall.rulecollections.buildsvr :
    azurerm_ip_group.this[_key].id
  ]
  firewall_policy_id = module.fwpolicy[0].resource_id
}