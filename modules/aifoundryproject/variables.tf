variable "canonical_name" {
  description = "Engine-emitted canonical Azure resource name."
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
  description = "Full Azure region name (e.g. uksouth)."
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

# ----- C-014 (Amendment 2026-05-31) — Shared hub Log Analytics wiring -----
variable "shared_log_analytics_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace where this resource emits its diagnostic settings. See specs/006-services/spec.md C-014."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.OperationalInsights/workspaces/.+$", var.shared_log_analytics_workspace_id))
    error_message = "shared_log_analytics_workspace_id must be a full Azure resource ID of the form /subscriptions/<sub>/.../providers/Microsoft.OperationalInsights/workspaces/<name> (spec.md C-014)."
  }
}

variable "diagnostic_settings_enabled" {
  description = "Operator escape hatch: set to false to skip the default azurerm_monitor_diagnostic_setting wiring to the shared hub LA. Default true preserves the C-014 contract."
  type        = bool
  default     = true
}

# ----- C-015 (Amendment 2026-05-31) — Project must point at its parent Hub -----
variable "hub_resource_id" {
  description = "Azure resource ID of the parent AI Foundry Hub (Microsoft.MachineLearningServices/workspaces with kind=Hub). The Project workspace declares this as hubResourceId."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.MachineLearningServices/workspaces/.+$", var.hub_resource_id))
    error_message = "hub_resource_id must be a full Microsoft.MachineLearningServices/workspaces resource ID (spec.md C-015)."
  }
}
