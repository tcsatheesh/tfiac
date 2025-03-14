
data "azurerm_private_dns_zone" "this" {
  for_each            = tomap(var.dns.domain_names)
  provider            = azurerm.dns
  name                = each.value
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}
