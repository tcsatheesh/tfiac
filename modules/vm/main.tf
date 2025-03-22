module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = var.buildsvr.location
  cache_results = true

  vm_filters = {
    min_vcpus                      = 8
    max_vcpus                      = 8
    encryption_at_host_supported   = true
    accelerated_networking_enabled = true
    premium_io_supported           = true
    location_zone                  = var.buildsvr.zone
  }
  enable_telemetry = false
}

module "buildsvr" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.17.0
  enable_telemetry    = false
  location            = var.buildsvr.location
  resource_group_name = var.buildsvr.resource_group_name
  os_type             = var.buildsvr.os_type
  name                = var.buildsvr.name
  sku_size            = module.vm_sku.sku
  zone                = var.buildsvr.zone


  source_image_reference = var.buildsvr.source_image_reference

  network_interfaces = {
    network_interface_1 = {
      name                = var.buildsvr.vnet.nic.name
      resource_group_name = var.vnet.resource_group_name
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${var.buildsvr.name}-ipconfig1"
          private_ip_subnet_resource_id = data.azurerm_subnet.this.id
        }
      }
      diagnostic_settings = {
        nic_diags = {
          name                  = "${var.buildsvr.name}-ipconfig1-to-la"
          workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  data_disk_managed_disks = {
    disk1 = {
      name                 = var.buildsvr.disk1.name
      storage_account_type = var.buildsvr.disk1.storage_account_type
      lun                  = 0
      caching              = var.buildsvr.disk1.caching
      disk_size_gb         = var.buildsvr.disk1.size
    }
  }

  shutdown_schedules = {
    shutdown = {
      daily_recurrence_time = "1900"
      enabled               = true
      timezone              = "Greenwich Standard Time"
      notification_settings = {
        enabled         = false
        email           = "example@example.com;example2@example.com"
        time_in_minutes = "15"
        webhook_url     = "https://example-webhook-url.example.com"
      }
    }
  }

  diagnostic_settings = {
    vm_diags = {
      name                  = "${var.buildsvr.name}-vm-to-la"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
      metric_categories     = ["AllMetrics"]
    }
  }
}