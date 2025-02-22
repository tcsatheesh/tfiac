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

locals {
  endpoints = toset(["blob", "queue", "table", "file"])
}

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
  storage_use_azuread = true
}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = local.vnet.vnet_subscription_id
}


provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = local.log.log_analytics_workspace_subscription_id
}

provider "azurerm" {
  features {}
  alias           = "private_dns"
  subscription_id = local.dns.dns_subscription_id
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = local.vnet.subnet_name
  vnet_name = local.vnet.vnet_name
  resource_group_name  = local.vnet.vnet_resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  for_each = local.endpoints

  name                = "privatelink.${each.value}.core.windows.net"
  resource_group_name = local.dns.dns_resource_group_name
  provider            = azurerm.private_dns
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = local.log.log_analytics_workspace_name
  resource_group_name = local.log.log_analytics_workspace_resource_group_name
}

# We need this to get the object_id of the current user
data "azurerm_client_config" "current" {}

locals {
  storage_account_name = var.storage_type == "landing" ? local.services.landing_storage_account_name : (var.storage_type == "aml" ? local.services.aml_storage_account_name : (var.storage_type == "function_app" ? local.services.function_app_storage_account_name : local.services.logic_app_storage_account_name))
}
module "this" {

  source = "Azure/avm-res-storage-storageaccount/azurerm"

  account_replication_type                = "LRS"
  account_tier                            = "Standard"
  account_kind                            = "StorageV2"
  location                                = local.services.location
  name                                    = local.storage_account_name
  https_traffic_only_enabled              = true
  resource_group_name                     = local.services.resource_group_name
  min_tls_version                         = "TLS1_2"
  shared_access_key_enabled               = false
  public_network_access_enabled           = false
  enable_telemetry                        = true
  private_endpoints_manage_dns_zone_group = true
  #create a private endpoint for each endpoint type
  private_endpoints = {
    for endpoint in local.endpoints :
    endpoint => {
      # the name must be set to avoid conflicting resources.
      name                          = "pe-${endpoint}-${local.storage_account_name}"
      subnet_resource_id            = data.azurerm_subnet.this.id
      subresource_name              = endpoint
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.this[endpoint].id]
      # these are optional but illustrate making well-aligned service connection & NIC names.
      private_service_connection_name = "psc-${endpoint}-${local.storage_account_name}"
      network_interface_name          = "nic-pe-${endpoint}-${local.storage_account_name}"
      inherit_lock                    = false
      resource_group_name             = local.vnet.vnet_resource_group_name
    }
  }
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
  diagnostic_settings_storage_account = {
    storage = {
      name                  = "diag"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_categories        = ["audit", "alllogs"]
      metric_categories     = ["Capacity", "Transaction"]
    }
  }

  # setting up diagnostic settings for queue
  diagnostic_settings_queue = {
    queue = {
      name                  = "diag"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_categories        = ["audit", "alllogs"]
      metric_categories     = ["Capacity", "Transaction"]
    }
  }

  # setting up diagnostic settings for table
  diagnostic_settings_table = {
    table = {
      name                  = "diag"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_categories        = ["audit", "alllogs"]
      metric_categories     = ["Capacity", "Transaction"]
    }
  }

  # setting up diagnostic settings for file
  diagnostic_settings_file = {
    file1 = {
      name                  = "diag"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_categories        = ["audit", "alllogs"]
      metric_categories     = ["Capacity", "Transaction"]
    }
  }

  # setting up diagnostic settings for blob
  diagnostic_settings_blob = {
    blob11 = {
      name                  = "diag"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      log_categories        = ["audit", "alllogs"]
      metric_categories     = ["Capacity", "Transaction"]
    }
  }
}
