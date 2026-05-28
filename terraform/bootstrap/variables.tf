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
  description = "Environment token for the tooling stack (default: tooling)."
  type        = string
  default     = "tool"
}
