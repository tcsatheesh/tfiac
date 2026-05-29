terraform {
  required_version = "~> 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
      # Constitution IX EXCEPTION: peering requires dual-provider wiring so
      # both halves of the peering land in the right subscription. See README.
      configuration_aliases = [azurerm.this, azurerm.hub]
    }
  }
}
