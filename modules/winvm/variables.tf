# Wrapper module inputs.
# Intent-only per Constitution II. Operators set high-level facts; we never
# expose AVM-module-shaped objects through this contract.

variable "input" {
  description = "Engine input bundle (passed straight through to modules/naming). Tenant/environment/region/usecase/stack_purpose/repo intent."
  type = object({
    tenant        = string
    environment   = string
    region        = string
    usecase       = string
    stack_purpose = string
    repo          = string
  })
}

variable "resource_group_name" {
  description = "Name of the EXISTING resource group the VM lands in. The engine references it (data source) and creates NO resource group (FR-813)."
  type        = string

  validation {
    condition     = can(regex("^rg-[A-Za-z0-9._-]{1,87}$", var.resource_group_name))
    error_message = "resource_group_name must be an rg-prefixed name (<=90 chars)."
  }
}

variable "subnet_resource_id" {
  description = "Azure resource ID of the existing spoke subnet (consumed from the vnet stack remote state). The VM NIC lands here (FR-806)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_resource_id))
    error_message = "subnet_resource_id must be a full Azure subnet resource id."
  }
}

variable "log_workspace_resource_id" {
  description = "Azure resource ID of the shared hub Log Analytics workspace for VM + NIC diagnostic settings (FR-815)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.log_workspace_resource_id))
    error_message = "log_workspace_resource_id must be a full Azure Log Analytics workspace resource id."
  }
}

variable "key_vault_id" {
  description = "Azure resource ID of the EXISTING Key Vault that stores the generated admin password secret (FR-809). The engine writes the secret here and grants the apply identity + VM MI the required roles."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.KeyVault/vaults/[^/]+$", var.key_vault_id))
    error_message = "key_vault_id must be a full Azure Key Vault resource id."
  }
}

variable "vm_sku" {
  description = "Azure VM size. Default Standard_D4s_v5 (4 vCPU, 16 GiB, x86_64). FR-805."
  type        = string
  default     = "Standard_D4s_v5"

  validation {
    condition     = can(regex("^Standard_[A-Za-z0-9_]+$", var.vm_sku))
    error_message = "WIN-INV-10: vm_sku must match ^Standard_[A-Za-z0-9_]+$."
  }
}

variable "zone" {
  description = "Availability zone for the VM (string \"1\", \"2\", or \"3\")."
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2", "3"], var.zone)
    error_message = "zone must be one of \"1\", \"2\", \"3\"."
  }
}

variable "source_image_reference" {
  description = "Marketplace image reference. Default Windows Server 2022 Datacenter Azure Edition (FR-805)."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

variable "admin_username" {
  description = "Windows local administrator account username. Default azureadmin. Must not be a reserved Windows name."
  type        = string
  default     = "azureadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]{1,19}$", var.admin_username)) && !contains(["administrator", "admin", "user", "guest", "root", "system"], lower(var.admin_username))
    error_message = "admin_username must be 2-20 chars, start with a letter, and not be a reserved Windows name (administrator, admin, user, guest, root, system)."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB. FR-814."
  type        = number
  default     = 128

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "WIN-INV-5: os_disk_size_gb must be in [30, 4095]."
  }
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage SKU. FR-814."
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be a supported managed disk SKU."
  }
}

variable "kv_rbac_propagation_seconds" {
  description = "Seconds to wait for Key Vault Secrets Officer RBAC to propagate before writing the secret (C-008-07). Default 120s."
  type        = number
  default     = 120

  validation {
    condition     = var.kv_rbac_propagation_seconds >= 0 && var.kv_rbac_propagation_seconds <= 600
    error_message = "kv_rbac_propagation_seconds must be in [0, 600]."
  }
}
