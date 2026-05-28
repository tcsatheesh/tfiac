###############################################################################
# terraform/bootstrap/providers.tf
#
# Bootstrap uses the LOCAL backend (this stack creates the remote-state
# storage account; it cannot store its own state there). Commit
# `bootstrap.tfstate` to a secure location (e.g. an encrypted vault) — it is
# small and rarely changes.
###############################################################################

terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Local backend (default) — do NOT add a backend "azurerm" block here.
}

provider "azurerm" {
  features {}

  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}
