variable "dns" {}

# create the resource group
resource "azurerm_resource_group" "avmrg" {
  name     = var.dns.resource_group_name
  location = var.dns.location
}

# reference the module and pass in variables as needed
module "private_dns_zones" {
  for_each = tomap(var.dns.domain_names)
  # replace source with the correct link to the private_dns_zones module
  source              = "Azure/avm-res-network-privatednszone/azurerm"
  resource_group_name = azurerm_resource_group.avmrg.name
  domain_name         = each.value
}