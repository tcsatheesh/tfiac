terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  resource_provider_registrations = "none"
  storage_use_azuread             = true
}
locals {
    storage      = yamldecode(file("../../variables/global/npd/tfs.yaml"))
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = local.storage.tf_backend_location
  name     = local.storage.tf_backend_resource_group_name
}

# We need this to get the object_id of the current user
data "azurerm_client_config" "current" {}


module "storage_account" {

  source = "Azure/avm-res-storage-storageaccount/azurerm"

  account_replication_type   = "LRS"
  account_tier               = "Standard"
  account_kind               = "StorageV2"
  location                   = azurerm_resource_group.this.location
  name                       = local.storage.tf_backend_storage_account_name
  https_traffic_only_enabled = true
  resource_group_name        = azurerm_resource_group.this.name
  min_tls_version            = "TLS1_2"
  shared_access_key_enabled  = true
  public_network_access_enabled = true

  containers = {
    blob_container0 = {
      name = local.storage.tf_backend_container_name
    }
  }
}