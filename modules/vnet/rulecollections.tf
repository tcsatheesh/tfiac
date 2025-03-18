module "denyall" {
  source             = "./rulecollection/denyall"
  firewall_policy_id = module.fwpolicy[0].resource_id
}

data "azurerm_ip_group" "this" {
  for_each            = tomap(var.firewall.ipgroups)
  name                = each.value.name
  resource_group_name = var.firewall.resource_group_name
}


module "azuread" {
  source = "./rulecollection/azuread"
  source_ip_groups = [for _key in var.firewall.rulecollections.azuread.ipgroups :
    data.azurerm_ip_group.this[_key].id
  ]
  firewall_policy_id         = module.fwpolicy[0].resource_id
  rule_collection_group_name = var.firewall.rulecollections.azuread.name
  depends_on                 = [azurerm_ip_group.this]
}

module "aml" {
  source = "./rulecollection/aml"
  source_ip_groups = [for _key in var.firewall.rulecollections.aml.ipgroups :
    data.azurerm_ip_group.this[_key].id
  ]
  firewall_policy_id         = module.fwpolicy[0].resource_id
  rule_collection_group_name = var.firewall.rulecollections.aml.name
  depends_on                 = [azurerm_ip_group.this]
}

module "buildsvr" {
  source = "./rulecollection/buildsvr"
  source_ip_groups = [for _key in var.firewall.rulecollections.buildsvr.ipgroups :
    data.azurerm_ip_group.this[_key].id
  ]
  firewall_policy_id         = module.fwpolicy[0].resource_id
  rule_collection_group_name = var.firewall.rulecollections.buildsvr.name
  depends_on                 = [azurerm_ip_group.this]
}