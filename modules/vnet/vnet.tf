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
    devFunctionApp = {
      name                            = var.vnet.dev_function_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.dev_function_app_subnet_address_prefixes
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
    devLogicApp = {
      name                            = var.vnet.dev_logic_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.dev_logic_app_subnet_address_prefixes
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
    pre = {
      name                            = var.vnet.pre_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_subnet_address_prefixes
    }
    preFunctionApp = {
      name                            = var.vnet.pre_function_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_function_app_subnet_address_prefixes
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
    preLogicApp = {
      name                            = var.vnet.pre_logic_app_subnet_name
      default_outbound_access_enabled = false
      address_prefixes                = var.vnet.pre_logic_app_subnet_address_prefixes
      delegation = [
        {
          name = "Microsoft.Web.serverFarms"
          service_delegation = {
            name = "Microsoft.Web/serverFarms"
          }
        }
      ]
    }
  }
}
