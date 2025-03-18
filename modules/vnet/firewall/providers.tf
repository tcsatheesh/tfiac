terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases = [
        azurerm.vnet,
        azurerm.log,
        azurerm.remote_vnet,
      azurerm.dns]
    }
  }
}
