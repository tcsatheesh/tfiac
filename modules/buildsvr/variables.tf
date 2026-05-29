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

variable "subnet_resource_id" {
  description = "Azure resource ID of the existing buildsvr subnet (consumed from the hub vnet stack remote state)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_resource_id))
    error_message = "subnet_resource_id must be a full Azure subnet resource id."
  }
}

variable "log_workspace_resource_id" {
  description = "Azure resource ID of the hub Log Analytics workspace for VM + NIC diagnostic settings."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.log_workspace_resource_id))
    error_message = "log_workspace_resource_id must be a full Azure Log Analytics workspace resource id."
  }
}

variable "vm_sku" {
  description = "Azure VM size. Default Standard_D4s_v5 (4 vCPU, 16 GiB, x86_64). FR-505 (BLD-INV-10)."
  type        = string
  default     = "Standard_D4s_v5"

  validation {
    condition     = can(regex("^Standard_[A-Za-z0-9_]+$", var.vm_sku))
    error_message = "BLD-INV-10: vm_sku must match ^Standard_[A-Za-z0-9_]+$."
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
  description = "Marketplace image reference. Default Ubuntu 22.04 LTS gen2."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "admin_username" {
  description = "Linux admin account username. Default azureuser."
  type        = string
  default     = "azureuser"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{1,31}$", var.admin_username))
    error_message = "admin_username must match ^[a-z][a-z0-9_-]{1,31}$."
  }
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the admin account. REQUIRED. FR-508."
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must start with one of: ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp256."
  }
}

variable "disable_password_authentication" {
  description = "Forbid password auth. MUST be true (BLD-INV-7)."
  type        = bool
  default     = true

  validation {
    condition     = var.disable_password_authentication == true
    error_message = "BLD-INV-7: disable_password_authentication must be true (SSH key only)."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB. FR-509."
  type        = number
  default     = 64

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "BLD-INV-5: os_disk_size_gb must be in [30, 4095]."
  }
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage SKU."
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be a supported managed disk SKU."
  }
}

variable "data_disk_size_gb" {
  description = "Data disk size in GiB. Mounted at /mnt/runner by cloud-init. FR-509."
  type        = number
  default     = 128

  validation {
    condition     = var.data_disk_size_gb >= 32 && var.data_disk_size_gb <= 4095
    error_message = "BLD-INV-5: data_disk_size_gb must be in [32, 4095]."
  }
}

variable "data_disk_storage_account_type" {
  description = "Data disk storage SKU."
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"], var.data_disk_storage_account_type)
    error_message = "data_disk_storage_account_type must be a supported managed disk SKU."
  }
}

variable "github_runner_url" {
  description = "GitHub URL for runner registration. Repo or org scope. Default https://github.com/tcsatheesh/tfiac."
  type        = string
  default     = "https://github.com/tcsatheesh/tfiac"

  validation {
    condition     = can(regex("^https://github\\.com/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?$", var.github_runner_url))
    error_message = "github_runner_url must be a github.com URL."
  }
}

variable "github_runner_token" {
  description = "GitHub Actions runner registration token (sensitive). Empty string skips registration (binary still installed). FR-511."
  type        = string
  default     = ""
  sensitive   = true
}

variable "runner_labels" {
  description = "Self-hosted runner labels."
  type        = list(string)
  default     = ["self-hosted", "linux", "hub-npd"]

  validation {
    condition     = length(var.runner_labels) >= 1
    error_message = "runner_labels must contain at least one label."
  }
}

variable "github_runner_version" {
  description = "GitHub Actions runner release version (without leading v)."
  type        = string
  default     = "2.319.1"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.github_runner_version))
    error_message = "github_runner_version must be semver MAJOR.MINOR.PATCH."
  }
}

variable "identity_role_assignments" {
  description = "Extra RBAC role assignments for the system-assigned managed identity. Each entry { scope_resource_id, role_definition_id_or_name, description? }. Day-one default grants Reader on the subscription (set via root stack)."
  type = map(object({
    scope_resource_id          = string
    role_definition_id_or_name = string
    description                = optional(string)
  }))
  default = {}
}
