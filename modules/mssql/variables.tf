variable "canonical_name" {
  description = "Engine-emitted canonical Azure SQL logical server name."
  type        = string

  validation {
    condition     = length(var.canonical_name) > 0 && length(var.canonical_name) <= 63
    error_message = "canonical_name must be non-empty and <= 63 chars (Azure SQL server name limit)."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.canonical_name))
    error_message = "canonical_name must match ^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$ (SQL server naming: lowercase alnum + hyphen, no leading/trailing hyphen)."
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

# ----- Shared hub Log Analytics wiring (C-014 parity) -----
variable "shared_log_analytics_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace where the database emits diagnostic settings."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.OperationalInsights/workspaces/.+$", var.shared_log_analytics_workspace_id))
    error_message = "shared_log_analytics_workspace_id must be a full Azure resource ID of an Operational Insights workspace."
  }
}

variable "diagnostic_settings_enabled" {
  description = "Escape hatch: set false to skip the default diagnostic-setting wiring to the shared hub LA. Document the opt-out reason in the PR body."
  type        = bool
  default     = true
}

# ----- Entra-only administration (no SQL auth, no password/secret) -----
variable "entra_admin_login" {
  description = "Display name of the Entra principal set as the SQL server's Azure AD administrator (azuread_authentication_only = true; no SQL login/password exists)."
  type        = string

  validation {
    condition     = length(var.entra_admin_login) > 0
    error_message = "entra_admin_login must be non-empty (Entra-only auth requires an AAD administrator)."
  }
}

variable "entra_admin_object_id" {
  description = "Object (principal) id of the Entra administrator. Typically the deploying CI service principal so the pipeline can manage database-level users."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.entra_admin_object_id))
    error_message = "entra_admin_object_id must be a GUID."
  }
}

variable "entra_admin_tenant_id" {
  description = "Entra tenant id of the administrator principal. Null lets Azure infer the resource's home tenant."
  type        = string
  default     = null
}

# ----- Private endpoint (private-by-default; SQL is private-ONLY) -----
variable "private_endpoint_subnet_id" {
  description = "Resource ID of the subnet the SQL private-endpoint NIC lands in. Required (non-null)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.private_endpoint_subnet_id))
    error_message = "private_endpoint_subnet_id must be a full subnet resource ID."
  }
}

variable "private_dns_zone_ids" {
  description = "Hub private DNS zone resource IDs (privatelink.database.windows.net) the private endpoint registers A-records into. Required non-empty."
  type        = list(string)

  validation {
    condition     = length(var.private_dns_zone_ids) > 0
    error_message = "private_dns_zone_ids must be a non-empty list (SQL is private-only)."
  }
}
