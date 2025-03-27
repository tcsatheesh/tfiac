terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 5.0.0"
    }
  }
  backend "azurerm" {
    subscription_id      = "<DUMMY>"
    resource_group_name  = "<DUMMY>"
    storage_account_name = "<DUMMY>"
    container_name       = "<DUMMY>"
    key                  = "<DUMMY>"
    use_azuread_auth     = true
    use_oidc             = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id                 = local.services.subscription_id
  resource_provider_registrations = "none"
}

provider "azurerm" {
  features {}
  alias                           = "vnet"
  subscription_id                 = local.vnet.subscription_id
  resource_provider_registrations = "none"
}

provider "azurerm" {
  features {}
  alias                           = "log"
  subscription_id                 = local.log.subscription_id
  resource_provider_registrations = "none"
}

provider "azurerm" {
  features {}
  alias                           = "dns"
  subscription_id                 = local.dns.subscription_id
  resource_provider_registrations = "none"
}

provider "azurerm" {
  features {}
  alias                           = "apim"
  subscription_id                 = local.services.apim.subscription_id
  resource_provider_registrations = "none"
}
