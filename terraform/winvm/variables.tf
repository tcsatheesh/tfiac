# Root-stack inputs.
# Scope dimensions validated here (WIN-INV-1/3/4). Subscription cross-checked at
# plan time by check.subscription_pinned in main.tf.

variable "subscription_id" {
  description = "Target Azure subscription id (GUID). Cross-checked at plan time (WIN-INV-3)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }
}

variable "repo" {
  description = "GitHub repo slug for the managed_by tag (case-preserving)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.repo)) && length(var.repo) <= 256
    error_message = "repo must match ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ and be <=256 chars."
  }
}

variable "region" {
  description = "Azure CAF short region code. Must be \"swc\" (WIN-INV-1)."
  type        = string

  validation {
    condition     = var.region == "swc"
    error_message = "WIN-INV-1: region must be \"swc\"."
  }
}

variable "tenant" {
  description = "Tenant identifier (e.g. sp01)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.tenant))
    error_message = "tenant must match ^[a-z0-9]{2,8}$."
  }
}

variable "environment" {
  description = "Environment short code (npd|prd|dev|pre) (WIN-INV-4)."
  type        = string

  validation {
    condition     = contains(["npd", "prd", "dev", "pre"], var.environment)
    error_message = "WIN-INV-4: environment must be one of [\"npd\", \"prd\", \"dev\", \"pre\"]."
  }
}

variable "usecase" {
  description = "Stack usecase token. Defaults to \"uc1\"."
  type        = string
  default     = "uc1"

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.usecase))
    error_message = "usecase must match ^[a-z0-9]{3,4}$."
  }
}

variable "stack_purpose" {
  description = "Stack purpose token used in the (existing) RG name lookup. Defaults to \"svc\" (the services RG that hosts the jump box)."
  type        = string
  default     = "svc"

  validation {
    condition     = can(regex("^[a-z0-9]{2,4}$", var.stack_purpose))
    error_message = "stack_purpose must match ^[a-z0-9]{2,4}$."
  }
}

variable "resource_group_name" {
  description = "Name of the EXISTING resource group the VM lands in (FR-813)."
  type        = string

  validation {
    condition     = can(regex("^rg-[A-Za-z0-9._-]{1,87}$", var.resource_group_name))
    error_message = "resource_group_name must be an rg-prefixed name (<=90 chars)."
  }
}

variable "subnet_role" {
  description = "Subnet role key looked up in the vnet stack remote-state subnets map (e.g. \"development\"). The VM NIC lands in this subnet."
  type        = string
  default     = "development"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,32}$", var.subnet_role))
    error_message = "subnet_role must match ^[a-z0-9-]{2,32}$."
  }
}

variable "key_vault_id" {
  description = "Azure resource id of the EXISTING Key Vault that stores the generated admin password secret (FR-809)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.KeyVault/vaults/[^/]+$", var.key_vault_id))
    error_message = "key_vault_id must be a full Azure Key Vault resource id."
  }
}

variable "vm_sku" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "zone" {
  description = "Availability zone."
  type        = string
  default     = "1"
}

variable "source_image_reference" {
  description = "Marketplace image reference (default Windows Server 2022 Datacenter Azure Edition)."
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
  description = "Windows local administrator username."
  type        = string
  default     = "azureadmin"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB."
  type        = number
  default     = 128
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage SKU."
  type        = string
  default     = "Premium_LRS"
}

variable "kv_rbac_propagation_seconds" {
  description = "Seconds to wait for KV Secrets Officer RBAC to propagate before the secret write (C-008-07)."
  type        = number
  default     = 120
}

variable "vnet_state_backend" {
  description = "Remote-state backend descriptor for the spoke vnet stack."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = optional(string)
  })
  default = null
}

variable "log_state_backend" {
  description = "Remote-state backend descriptor for the hub log stack."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = optional(string)
  })
  default = null
}

variable "vnet_state_override" {
  description = "TEST-ONLY: synthesize vnet remote-state outputs."
  type = object({
    subnet_resource_id = string
  })
  default = null
}

variable "log_state_override" {
  description = "TEST-ONLY: synthesize log remote-state outputs."
  type = object({
    workspace_resource_id = string
  })
  default = null
}
