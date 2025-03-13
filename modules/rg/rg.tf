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
  subscription_id = var.services.subscription_id
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  alias           = "vnet"
  subscription_id = var.vnet.subscription_id
}


resource "azurerm_resource_group" "vnet" {
  location = var.vnet.location
  name     = var.vnet.resource_group_name
  provider = azurerm.vnet
}

resource "azurerm_resource_group" "services" {
  location = var.services.location
  name     = var.services.resource_group_name
}