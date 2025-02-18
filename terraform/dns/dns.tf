locals {
  dns      = yamldecode(file("../../variables/global/prd/dns.yaml"))
}

provider "azurerm" {
  features {}
  subscription_id = local.dns.dns_subscription_id
}

# create the resource group
resource "azurerm_resource_group" "avmrg" {
  location = local.dns.dns_location
  name     = local.dns.dns_resource_group_name
}

# reference the module and pass in variables as needed
module "private_dns_zones" {
  for_each = tomap(local.dns.domain_names)
  # replace source with the correct link to the private_dns_zones module
  source                = "Azure/avm-res-network-privatednszone/azurerm"  
  enable_telemetry      = local.dns.enable_telemetry
  resource_group_name   = azurerm_resource_group.avmrg.name
  domain_name           = each.value
}