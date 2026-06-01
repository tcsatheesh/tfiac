variable "canonical_name" {
  description = "Engine-emitted canonical Azure resource name."
  type        = string

  validation {
    condition     = length(var.canonical_name) > 0 && length(var.canonical_name) <= 44
    error_message = "canonical_name must be non-empty and <= 44 chars (Cosmos DB account name limit)."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,42}[a-z0-9]$", var.canonical_name))
    error_message = "canonical_name must match ^[a-z0-9][a-z0-9-]{1,42}[a-z0-9]$ (Cosmos DB account naming rules: lowercase alnum + hyphen, no leading/trailing hyphen)."
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

# ----- C-014 (Amendment 2026-05-31) — Shared hub Log Analytics wiring -----
variable "shared_log_analytics_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace (provisioned by terraform/log/) where this resource emits its diagnostic settings. See spec.md C-014."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.OperationalInsights/workspaces/.+$", var.shared_log_analytics_workspace_id))
    error_message = "shared_log_analytics_workspace_id must be a full Azure resource ID of the form /subscriptions/<sub>/.../providers/Microsoft.OperationalInsights/workspaces/<name> (spec.md C-014)."
  }
}

variable "diagnostic_settings_enabled" {
  description = "Operator escape hatch: set to false to skip the default azurerm_monitor_diagnostic_setting wiring to the shared hub LA. Default true preserves the C-014 contract. Document the opt-out reason in the PR body."
  type        = bool
  default     = true
}

# ----- FR-032 (Amendment 2026-06-02) — Private endpoint (private-by-default) -----
# Unlike the toggle-based PE wrappers (cntreg/aifoundry), Cosmos DB is
# private-ONLY: public_network_access_enabled is ALWAYS false and the private
# endpoint is ALWAYS provisioned. Both inputs are therefore required (non-null /
# non-empty). This honours the private-by-default mandate for a brand-new
# service: there is no public variant.
variable "private_endpoint_subnet_id" {
  description = "FR-032: resource ID of the subnet the Cosmos DB private-endpoint NIC lands in. Required (non-null)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.private_endpoint_subnet_id))
    error_message = "private_endpoint_subnet_id must be a full subnet resource ID of the form /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>."
  }
}

variable "private_dns_zone_ids" {
  description = "FR-032: hub private DNS zone resource IDs (privatelink.documents.azure.com) the private endpoint registers A-records into. Required non-empty."
  type        = list(string)

  validation {
    condition     = length(var.private_dns_zone_ids) > 0
    error_message = "private_dns_zone_ids must be a non-empty list (Cosmos DB is private-only; FR-032)."
  }
}
