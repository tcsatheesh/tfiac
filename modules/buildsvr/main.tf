# Stack composition.
# Constitution VI: NO provider blocks here (declared in versions.tf only).
# Constitution IX: every Azure resource flows through AVM modules.

module "naming" {
  source = "../naming"

  input    = var.input
  services = local.engine_services
}

module "rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.4"

  name     = local.rg_canonical_name
  location = local.region_full
  tags     = module.naming.names[local.rg_canonical_name].tags

  enable_telemetry = false
}

module "vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.20"

  enable_telemetry = false

  name                = local.vm_canonical_name
  location            = local.region_full
  resource_group_name = module.rg.name
  zone                = var.zone
  os_type             = "Linux"
  sku_size            = var.vm_sku
  tags                = module.naming.names[local.vm_canonical_name].tags

  source_image_reference = var.source_image_reference

  os_disk = {
    name                 = local.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  data_disk_managed_disks = {
    (local.data_disk_key) = {
      name                 = local.data_disk_name
      storage_account_type = var.data_disk_storage_account_type
      lun                  = 0
      caching              = "ReadWrite"
      disk_size_gb         = var.data_disk_size_gb
    }
  }

  network_interfaces = {
    primary = {
      name = local.nic_name
      ip_configurations = {
        ipconfig1 = {
          name                          = "${local.vm_canonical_name}-ipconfig1"
          private_ip_subnet_resource_id = var.subnet_resource_id
          private_ip_address_allocation = "Dynamic"
        }
      }
      accelerated_networking_enabled = true
      diagnostic_settings = {
        nic_diags = {
          name                  = local.diag_nic_name
          workspace_resource_id = var.log_workspace_resource_id
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  diagnostic_settings = {
    vm_diags = {
      name                  = local.diag_vm_name
      workspace_resource_id = var.log_workspace_resource_id
      metric_categories     = ["AllMetrics"]
    }
  }

  account_credentials = {
    admin_credentials = {
      username                           = var.admin_username
      ssh_keys                           = [var.admin_ssh_public_key]
      generate_admin_password_or_ssh_key = false
    }
    password_authentication_disabled = var.disable_password_authentication
  }

  managed_identities = {
    system_assigned = true
  }

  role_assignments_system_managed_identity = var.identity_role_assignments

  custom_data = base64encode(local.cloud_init)

  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true
}
