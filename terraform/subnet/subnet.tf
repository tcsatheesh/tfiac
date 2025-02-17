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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_virtual_network" "this" {
  name                = local.vnet.virtual_network_name
  resource_group_name = local.vnet.virtual_network_resource_group_name
}

module "avm-res-network-subnet" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"

  virtual_network = {
    resource_id = data.azurerm_virtual_network.this.id
  }
  name             = local.vnet.subnet_name
  address_prefixes = local.vnet.subnet_address_prefixes
}