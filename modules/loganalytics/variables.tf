###############################################################################
# modules/loganalytics/variables.tf
###############################################################################

variable "naming" {
  description = "Passthrough of module.naming.names."
  type        = map(any)
}

variable "region" {
  description = "Azure region (e.g. swedencentral)."
  type        = string
}

variable "region_code" {
  description = "Short engine region code (e.g. sdc)."
  type        = string
}

variable "input" {
  description = "Engine input object (for baseline tag derivation and canonical names)."
  type = object({
    topology    = string
    tenant      = string
    environment = string
    region      = string
    repo        = string
    purpose     = optional(string, null)
    services    = optional(list(any), [])
    overrides   = optional(any, {})
  })
}

variable "retention_in_days" {
  description = "Workspace data retention. Default 30 (FR-105)."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730 (Azure platform limits)."
  }
}

variable "sku" {
  description = "Workspace SKU. Default PerGB2018."
  type        = string
  default     = "PerGB2018"

  validation {
    condition     = contains(["PerGB2018", "Free", "Standalone", "PerNode", "Premium", "Standard", "Unlimited", "CapacityReservation", "LACluster"], var.sku)
    error_message = "sku must be a valid Log Analytics workspace SKU."
  }
}
