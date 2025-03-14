module "this" {

  source = "Azure/avm-res-storage-storageaccount/azurerm"

  account_replication_type                = "LRS"
  account_tier                            = "Standard"
  account_kind                            = "StorageV2"
  location                                = var.services.location
  name                                    = var.storage_account_name
  https_traffic_only_enabled              = true
  resource_group_name                     = var.services.resource_group_name
  min_tls_version                         = "TLS1_2"
  shared_access_key_enabled               = var.shared_access_key_enabled
  public_network_access_enabled           = var.public_network_access_enabled
  network_rules                           = var.network_rules
  private_endpoints_manage_dns_zone_group = true
  #create a private endpoint for each endpoint type
  private_endpoints = {
    for endpoint in local.endpoints :
    endpoint => {
      # the name must be set to avoid conflicting resources.
      name                            = "pe-${endpoint}-${var.storage_account_name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      subresource_name                = endpoint
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this[endpoint].id]
      private_service_connection_name = "psc-${endpoint}-${var.storage_account_name}"
      network_interface_name          = "nic-pe-${endpoint}-${var.storage_account_name}"
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

output "storage_account_id" {
  value = module.this.resource_id
}

output "storage_account_name" {
  value = module.this.name
}

output "storage_account_key" {
  value = module.this.resource.primary_access_key
}
