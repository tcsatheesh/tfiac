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

resource "azurerm_resource_group" "this" {
  location = var.vnet.location
  name     = var.vnet.resource_group_name
}

resource "azurerm_resource_group" "this" {
  location = var.services.location
  name     = var.services.resource_group_name
}