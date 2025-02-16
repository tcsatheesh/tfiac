variable "location" {
    type = string
}
variable "dns_subscription_id" {
    type = string
  
}
variable "dns_resource_group_name" {
    type = string
}
variable "enable_telemetry" {
    type = bool
    default = true
  
}
variable "domain_name" {
    type = string
  
}

provider "azurerm" {
  features {}
  subscription_id = var.dns_subscription_id
}

# create the resource group
resource "azurerm_resource_group" "avmrg" {
  location = var.location
  name     = var.dns_resource_group_name
}

# reference the module and pass in variables as needed
module "private_dns_zones" {
  # replace source with the correct link to the private_dns_zones module
  source                = "Azure/avm-res-network-privatednszone/azurerm"  
#   source                = "../"
  enable_telemetry      = var.enable_telemetry
  resource_group_name   = azurerm_resource_group.avmrg.name
  domain_name           = var.domain_name

}