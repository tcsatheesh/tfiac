variable "storage_type" {
  type = string
  validation {
    condition     = var.storage_type == "landing" || var.storage_type == "aml" || var.storage_type == "function_app" || var.storage_type == "logic_app"
    error_message = "storage_type must be either landing, aml, function_app or logic_app"
  }
}
variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

locals {
  endpoints = toset(["blob", "queue", "table", "file"])
}

locals {
  storage_account_name = var.storage_type == "landing" ? var.services.landing_storage_account_name : (var.storage_type == "aml" ? var.services.aml_storage_account_name : (var.storage_type == "function_app" ? var.services.function_app_storage_account_name : var.services.logic_app_storage_account_name))
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
  subscription_id = var.vnet.subscription_id
}


provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = var.log.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "private_dns"
  subscription_id = var.dns.subscription_id
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  for_each = local.endpoints

  name                = var.dns.domain_names[each.value]
  resource_group_name = var.dns.resource_group_name
  provider            = azurerm.private_dns
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "this" {

  source = "Azure/avm-res-storage-storageaccount/azurerm"

  account_replication_type                = "LRS"
  account_tier                            = "Standard"
  account_kind                            = "StorageV2"
  location                                = var.services.location
  name                                    = local.storage_account_name
  https_traffic_only_enabled              = true
  resource_group_name                     = var.services.resource_group_name
  min_tls_version                         = "TLS1_2"
  shared_access_key_enabled               = false
  public_network_access_enabled           = false
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
      resource_group_name             = var.vnet.resource_group_name
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
