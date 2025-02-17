variable "market" {
  type = string
}
variable "environment" {
  type = string
}
variable "env_type" {
  type    = string
  default = "npd"
  validation {
    condition     = var.env_type == "prd" || var.env_type == "npd"
    error_message = "env_type must be either prd or npd"
  }
}

locals {
  dns      = yamldecode(file("../../variables/global/prd/dns.yaml"))
  log      = yamldecode(file("../../variables/global/${var.env_type}/log.yaml"))
  vnet     = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  services = yamldecode(file("../../variables/${var.market}/${var.environment}/services.yaml"))
}

terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.74"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = local.log.log_analytics_workspace_subscription_id
}

provider "azurerm" {
  features {}
  alias           = "private_dns"
  subscription_id = local.dns.dns_subscription_id
}

# This is required for resource modules
data "azurerm_resource_group" "this" {
  name = local.vnet.virtual_network_resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = local.dns.keyvault_private_dns_zone_name
  resource_group_name = local.dns.dns_resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = local.log.log_analytics_workspace_name
  resource_group_name = local.log.log_analytics_workspace_resource_group_name
}

# Creating a virtual network with a unique name, telemetry settings, and in the specified resource group and location.
module "vnet" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  name                = local.vnet.virtual_network_name
  enable_telemetry    = local.vnet.enable_telemetry
  resource_group_name = local.vnet.virtual_network_resource_group_name
  location            = local.vnet.virtual_network_location
  address_space       = local.vnet.virtual_network_address_space
}
