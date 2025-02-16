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
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = var.location
  name     = var.virtual_network_resource_group_name
}

# Creating a virtual network with a unique name, telemetry settings, and in the specified resource group and location.
module "vnet" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  name                = var.virtual_network_name
  enable_telemetry    = var.enable_telemetry
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = var.virtual_network_address_space
}
