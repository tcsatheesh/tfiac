data "azurerm_ip_group" "this" {
  for_each            = tomap(var.firewall.ipgroups)
  name                = each.value.name
  resource_group_name = var.firewall.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}
