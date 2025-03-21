resource "azurerm_ip_group" "this" {
  for_each            = tomap(var.firewall.ipgroups)
  name                = each.value.name
  location            = var.firewall.location
  resource_group_name = var.firewall.resource_group_name

  cidrs = each.value.cidrs
}