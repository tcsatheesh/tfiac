terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases = [
        azurerm.buildsvr,
        azurerm.log,
        azurerm.vnet,
        azurerm.dns
      ]
    }
  }
}
