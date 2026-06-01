variable "canonical_name" {
  description = "Engine-emitted canonical Azure resource name (cae-...)."
  type        = string

  validation {
    condition     = length(var.canonical_name) > 0 && length(var.canonical_name) <= 260
    error_message = "canonical_name must be non-empty and <= 260 chars."
  }

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.canonical_name))
    error_message = "canonical_name must match ^[a-z0-9.-]+$ (engine INV-7)."
  }
}

variable "resource_group_name" {
  description = "Services-stack RG name."
  type        = string

  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "resource_group_name must be non-empty."
  }
}

variable "location" {
  description = "Full Azure region name (e.g. swedencentral)."
  type        = string

  validation {
    condition     = length(var.location) > 0
    error_message = "location must be non-empty."
  }
}

variable "tags" {
  description = "Engine-emitted tag map."
  type        = map(string)
}

variable "engine_record" {
  description = "Full engine record from module.naming.names[canonical_name]."
  type = object({
    service_type    = string
    service_purpose = optional(string)
    stack_purpose   = optional(string)
    parent          = optional(string)
    tags            = map(string)
    azure_max       = number
  })
}

variable "overrides" {
  description = "Per-instance attribute override map merged on top of local.defaults."
  type        = map(any)
  default     = {}
}

# ----- C-014 — Shared hub Log Analytics wiring -----
variable "shared_log_analytics_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace the environment links to (var.log_analytics_workspace_id of the Managed Environment). See spec.md C-014/C-021."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.OperationalInsights/workspaces/.+$", var.shared_log_analytics_workspace_id))
    error_message = "shared_log_analytics_workspace_id must be a full Azure resource ID of the form /subscriptions/<sub>/.../providers/Microsoft.OperationalInsights/workspaces/<name> (spec.md C-014)."
  }
}

# ----- C-021 (FR-030) — internal (private) environment wiring -----
variable "infrastructure_subnet_id" {
  description = "C-021: resource ID of the spoke subnet (delegated to Microsoft.App/environments) the internal Managed Environment is VNet-injected into. Required, non-null."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.infrastructure_subnet_id))
    error_message = "infrastructure_subnet_id must be a full subnet resource ID of the form /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>."
  }
}

variable "vnet_id" {
  description = "C-021: resource ID of the spoke VNet the private default-domain DNS zone is linked to so apps resolve privately."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.vnet_id))
    error_message = "vnet_id must be a full virtualNetworks resource ID."
  }
}
