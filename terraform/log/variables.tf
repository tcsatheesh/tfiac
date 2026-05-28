###############################################################################
# terraform/log/variables.tf
###############################################################################

variable "subscription_id" {
  description = "Azure subscription GUID for the deployment target. Cross-checked by check.subscription_pinned."
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

# ─── env/scope discriminators ────────────────────────────────────────────────
# Required for every plan; they drive the naming engine input and the
# baseline tags. No defaults — the .tfvars file in variables/<env>/<scope>/
# is the single source of truth for which (env, scope) this plan targets.

variable "topology" {
  description = "Topology this deployment serves: \"hub\" for shared / centralized stacks, \"spoke\" for workload landing zones."
  type        = string

  validation {
    condition     = contains(["hub", "spoke"], var.topology)
    error_message = "topology must be \"hub\" or \"spoke\"."
  }
}

variable "tenant" {
  description = "Tenant code: \"hub\" for centralised hub services, otherwise the spoke code (e.g. \"sp01\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.tenant))
    error_message = "tenant must be lowercase alphanumerics (e.g. hub, sp01)."
  }
}

variable "environment" {
  description = "Environment lane: npd / pre / prd."
  type        = string

  validation {
    condition     = contains(["npd", "pre", "prd"], var.environment)
    error_message = "environment must be one of npd, pre, prd."
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
