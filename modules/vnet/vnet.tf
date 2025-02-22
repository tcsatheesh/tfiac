variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Creating a virtual network with a unique name, telemetry settings, and in the specified resource group and location.
module "vnet" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  name                = var.vnet.name
  enable_telemetry    = false
  resource_group_name = var.vnet.resource_group_name
  location            = var.vnet.location

  address_space = var.vnet.address_space

  subnets = {
    dev = {
      name                            = var.vnet.dev_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.dev_subnet_address_prefixes
    }
    pre = {
      name                            = var.vnet.pre_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_subnet_address_prefixes
    }
  }
}