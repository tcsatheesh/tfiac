module "denyall" {
  source             = "./rulecollection/denyall"
  firewall_policy_id = module.fwpolicy[0].resource_id
}

locals {
  azuread = [for _key in var.firewall.rulecollections.azuread :
    azurerm_ip_group.this[_key].id
  ]
}

module "azuread" {
  source             = "./rulecollection/azuread"
  source_ip_groups   = local.azuread
  firewall_policy_id = module.fwpolicy[0].resource_id
}