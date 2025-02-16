variable "virtual_network_resource_group_name" {
  type = string
}
variable "virtual_network_name" {
  type = string
}
variable "subnet_name" {
  type = string
}
variable "location" {
  type = string
}
variable "enable_telemetry" {
  type = bool
  default = true
}
variable "virtual_network_address_space" {
  type = list(string)
}
variable "subnet_address_prefixes" {
  type = list(string)
  
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
  name                = var.virtual_network_name
  resource_group_name = var.virtual_network_resource_group_name
}

module "avm-res-network-subnet" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"

  virtual_network = {
    resource_id = data.azurerm_virtual_network.this.id
  }
  name             = var.subnet_name
  address_prefixes = var.subnet_address_prefixes
}