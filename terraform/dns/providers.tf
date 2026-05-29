###############################################################################
# terraform/dns/providers.tf  (feature 002 — replaces legacy provider config)
#
# Pinned Terraform + AzureRM versions; provider features {} block; subscription
# pinned from var.subscription_id (the same value FR-029 cross-checks against
# data.azurerm_client_config.current).
###############################################################################

terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}
