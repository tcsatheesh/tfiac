# Stack composition.
# Constitution VI: NO provider blocks here (declared in versions.tf only).
# Constitution IX: the Azure VM flows through the AVM module. The remaining
# resources (random_password, key_vault_secret, role_assignment, time_sleep)
# are secret-management glue with no AVM equivalent.

data "azurerm_client_config" "current" {}

# FR-813 — reference the EXISTING resource group (fail fast if absent). Provides
# the location for the VM; the engine creates no resource group.
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

module "naming" {
  source = "../naming"

  input    = var.input
  services = local.engine_services
}

# FR-809 — Terraform-generated local admin password. Never sourced from tfvars.
resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

module "vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.20"

  enable_telemetry = false

  name                = local.vm_canonical_name
  computer_name       = local.computer_name
  location            = local.region_full
  resource_group_name = data.azurerm_resource_group.existing.name
  zone                = var.zone
  os_type             = "Windows"
  sku_size            = var.vm_sku
  tags                = module.naming.names[local.vm_canonical_name].tags

  source_image_reference = var.source_image_reference

  os_disk = {
    name                 = local.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # FR-806 — single NIC, dynamic private IP in the spoke subnet, NO public IP.
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

  # FR-809 — Windows local admin uses the generated password (no SSH keys).
  account_credentials = {
    admin_credentials = {
      username                           = var.admin_username
      password                           = random_password.admin.result
      generate_admin_password_or_ssh_key = false
    }
    # AVM requires this true for os_type=Windows; it gates SSH/password-auth
    # toggling on Linux only and is inert for Windows (password still used).
    password_authentication_disabled = true
  }

  # FR-807 — system-assigned managed identity.
  managed_identities = {
    system_assigned = true
  }

  # FR-812 — Entra ID login over Bastion.
  extensions = {
    aad_login = {
      name                       = "AADLoginForWindows"
      publisher                  = "Microsoft.Azure.ActiveDirectory"
      type                       = "AADLoginForWindows"
      type_handler_version       = "2.0"
      auto_upgrade_minor_version = true
    }
  }

  # FR-808 — security baseline.
  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true
}

# FR-810 / C-008-07 — grant the apply identity permission to write the secret,
# then wait for RBAC propagation before the write so a fresh deployer succeeds.
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "kv_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_secrets_officer]
  create_duration = "${var.kv_rbac_propagation_seconds}s"
}

# FR-809 — store the generated admin password in the existing Key Vault.
resource "azurerm_key_vault_secret" "admin_password" {
  name         = local.admin_password_secret_name
  value        = random_password.admin.result
  key_vault_id = var.key_vault_id
  content_type = "text/plain; vm-local-admin-password"
  tags         = module.naming.names[local.vm_canonical_name].tags

  depends_on = [time_sleep.kv_rbac]
}

# FR-811 — VM managed identity gets break-glass read on the Key Vault.
resource "azurerm_role_assignment" "vm_mi_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.vm.system_assigned_mi_principal_id
}
