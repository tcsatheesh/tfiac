variable "market" {
  type = string
}
variable "environment" {
  type = string
}
variable "env_type" {
  type    = string
  default = "npd"
  validation {
    condition     = var.env_type == "prd" || var.env_type == "npd"
    error_message = "env_type must be either prd or npd"
  }
}
variable "storage_type" {
  type = string
  validation {
    condition     = var.storage_type == "landing" || var.storage_type == "aml" || var.storage_type == "function_app" || var.storage_type == "logic_app"
    error_message = "storage_type must be either landing, aml, function_app or logic_app"
  }
}

locals {
  dns      = yamldecode(file("../../variables/global/prd/dns.yaml"))
  log      = yamldecode(file("../../variables/global/${var.env_type}/log.yaml"))
  vnet     = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  services = yamldecode(file("../../variables/${var.market}/${var.environment}/services.yaml"))
}

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

# We need this to get the object_id of the current user
data "azurerm_client_config" "current" {}


module "storage_account" {

  source = "Azure/avm-res-storage-storageaccount/azurerm"

  account_replication_type      = "LRS"
  account_tier                  = "Standard"
  account_kind                  = "StorageV2"
  location                      = local.services.location
  name                          = var.storage_type == "landing" ? local.services.landing_storage_account_name : (var.storage_type == "aml" ? local.services.aml_storage_account_name : (var.storage_type == "function_app" ? local.services.function_app_storage_account_name : local.services.logic_app_storage_account_name))
  https_traffic_only_enabled    = true
  resource_group_name           = local.services.resource_group_name
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = false
  public_network_access_enabled = false

  containers = {
    blob_container0 = {
      name = "raw"
    }
    blob_container1 = {
      name = "structured"
    }
    blob_container2 = {
      name = "curated"
    }
  }
}
