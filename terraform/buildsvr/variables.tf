variable "subscription_id" {
  description = "Target Azure subscription id (GUID). Cross-checked at plan time."
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
  description = "Azure CAF short region code. Must be \"swc\" (BLD-INV-1)."
  type        = string

  validation {
    condition     = var.region == "swc"
    error_message = "BLD-INV-1: region must be \"swc\"."
  }
}

variable "tenant" {
  description = "Tenant identifier. Must be \"hub\" (BLD-INV-4)."
  type        = string

  validation {
    condition     = var.tenant == "hub"
    error_message = "BLD-INV-4: tenant must be \"hub\" (this stack is hub-only)."
  }
}

variable "environment" {
  description = "Environment short code (npd|prd) (BLD-INV-2)."
  type        = string

  validation {
    condition     = contains(["npd", "prd"], var.environment)
    error_message = "BLD-INV-2: environment must be one of [\"npd\", \"prd\"]."
  }
}

variable "usecase" {
  description = "Stack usecase. Defaults to \"shd\"."
  type        = string
  default     = "shd"

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.usecase))
    error_message = "usecase must match ^[a-z0-9]{3,4}$."
  }
}

variable "zone" {
  description = "Availability zone."
  type        = string
  default     = "1"
}

variable "vm_sku" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "source_image_reference" {
  description = "Marketplace image reference."
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
  type    = string
  default = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the admin account. REQUIRED."
  type        = string
}

variable "os_disk_size_gb" {
  type    = number
  default = 64
}

variable "data_disk_size_gb" {
  type    = number
  default = 128
}

variable "github_runner_url" {
  type    = string
  default = "https://github.com/tcsatheesh/tfiac"
}

variable "github_runner_token" {
  description = "GitHub Actions runner registration token (sensitive). Empty skips registration."
  type        = string
  default     = ""
  sensitive   = true
}

variable "runner_labels" {
  type    = list(string)
  default = ["self-hosted", "linux", "hub-npd"]
}

variable "github_runner_version" {
  type    = string
  default = "2.319.1"
}

variable "identity_role_assignments" {
  description = "Role assignments for the system-assigned MI. Default Reader on the subscription is added by locals.tf."
  type = map(object({
    scope_resource_id          = string
    role_definition_id_or_name = string
    description                = optional(string)
  }))
  default = {}
}

variable "assign_subscription_reader" {
  description = "When true (default), the wrapper merges a Reader-on-subscription assignment into identity_role_assignments."
  type        = bool
  default     = true
}

variable "vnet_state_backend" {
  description = "Remote-state backend descriptor for the hub vnet stack."
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
  description = "TEST-ONLY: synthesize hub vnet remote-state outputs."
  type = object({
    subnet_resource_id = string
  })
  default = null
}

variable "log_state_override" {
  description = "TEST-ONLY: synthesize hub log remote-state outputs."
  type = object({
    workspace_resource_id = string
  })
  default = null
}
