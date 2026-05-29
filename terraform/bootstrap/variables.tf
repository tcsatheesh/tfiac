###############################################################################
# terraform/bootstrap/variables.tf
#
# Inputs for the tfstate-storage bootstrap. Keep this stack tiny — only the
# resources needed to host remote state for every other stack in the repo.
###############################################################################

variable "subscription_id" {
  description = "Azure subscription that will host the tfstate storage account."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "region" {
  description = "Azure region for the tfstate storage account (must be allowed by the naming engine)."
  type        = string
  default     = "swedencentral"
}

variable "repo" {
  description = "Consumer repository identifier (FR-001) — passed to the naming engine."
  type        = string
}

variable "environment" {
  description = "Environment token for the tooling stack (e.g. \"npd\" or \"prd\"). Bootstrap stacks are deployed per-environment so the tfstate storage account stays scoped to a single subscription/env."
  type        = string

  validation {
    condition     = contains(["npd", "prd"], var.environment)
    error_message = "environment must be one of: npd, prd."
  }
}

variable "purpose" {
  description = "Purpose segment for the tooling RG (default: \"tool\"). Produces canonical RG name `rg-{tenant}-{environment}-{purpose}-{region_code}-001`."
  type        = string
  default     = "tool"
}
