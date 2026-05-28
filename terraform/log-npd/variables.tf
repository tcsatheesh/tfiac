###############################################################################
# terraform/log-npd/variables.tf
###############################################################################

variable "subscription_id" {
  description = "Azure subscription GUID for the npd hub. Cross-checked by check.subscription_pinned."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase GUID."
  }
}

variable "region" {
  description = "Azure region. Must be in local.allowed_regions (day-one: swedencentral)."
  type        = string

  validation {
    condition     = contains(["swedencentral"], var.region)
    error_message = "region must be one of the platform-approved regions (day-one: swedencentral)."
  }
}

variable "repo" {
  description = "Source repository identifier; flows into baseline tags."
  type        = string

  validation {
    condition     = length(var.repo) > 0
    error_message = "repo is required."
  }
}

variable "retention_in_days" {
  description = "Workspace retention (30..730). Default 30."
  type        = number
  default     = 30
}

variable "sku" {
  description = "Workspace SKU. Default PerGB2018."
  type        = string
  default     = "PerGB2018"
}
