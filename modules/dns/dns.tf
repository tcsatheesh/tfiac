variable "dns" {}

provider "azurerm" {
  features {}
  subscription_id = var.dns.subscription_id
}

# create the resource group
data "azurerm_resource_group" "avmrg" {
  name = var.dns.resource_group_name
}

# reference the module and pass in variables as needed
module "private_dns_zones" {
  for_each = tomap(var.dns.domain_names)
  # replace source with the correct link to the private_dns_zones module
  source              = "Azure/avm-res-network-privatednszone/azurerm"
  resource_group_name = var.dns.resource_group_name
  domain_name         = each.value
}