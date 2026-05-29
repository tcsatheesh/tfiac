# T012 - root-stack inputs.
# Scope dimensions (topology, tenant, region) are hard-pinned at this layer
# via validation blocks (LOG-INV-1..3). Environment accepts {npd, prd} only
# (LOG-INV-4). Subscription is cross-checked at plan time by check.subscription_match
# in main.tf (LOG-INV-5).

variable "subscription_id" {
  description = "Azure subscription ID. Cross-checked at plan time against data.azurerm_client_config (FR-109)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }
}

variable "region" {
  description = "Azure region short code. Must be 'swc' (swedencentral) for the log analytics hub stack (LOG-INV-1)."
  type        = string

  validation {
    condition     = contains(["swc"], var.region)
    error_message = "LOG-INV-1: region must be \"swc\" (swedencentral). Got: ${var.region}."
  }
}

variable "repo" {
  description = "Source repository slug for the managed_by trail."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.repo)) && length(var.repo) <= 256
    error_message = "repo must match ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ and be <=256 chars."
  }
}

variable "topology" {
  description = "Topology discriminator. Must be 'hub' for the centralised log analytics stack (LOG-INV-2)."
  type        = string

  validation {
    condition     = contains(["hub"], var.topology)
    error_message = "LOG-INV-2: topology must be \"hub\". Got: ${var.topology}."
  }
}

variable "tenant" {
  description = "Tenant identifier. Must be 'hub' for the centralised log analytics stack (LOG-INV-3)."
  type        = string

  validation {
    condition     = contains(["hub"], var.tenant)
    error_message = "LOG-INV-3: tenant must be \"hub\". Got: ${var.tenant}."
  }
}

variable "environment" {
  description = "Environment short code. Must be 'npd' or 'prd' (LOG-INV-4)."
  type        = string

  validation {
    condition     = contains(["npd", "prd"], var.environment)
    error_message = "LOG-INV-4: environment must be one of [\"npd\", \"prd\"]. Got: ${var.environment}."
  }
}

variable "retention_in_days" {
  description = "Log Analytics workspace retention in days. Integer in [30, 730] (LOG-INV-6, FR-105)."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "LOG-INV-6: retention_in_days must be an integer in [30, 730]. Got: ${var.retention_in_days}."
  }
}

variable "daily_quota_gb" {
  description = "Log Analytics workspace daily ingestion quota in GB. -1 (unlimited) or any positive integer (LOG-INV-7, FR-105)."
  type        = number
  default     = -1

  validation {
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb >= 1
    error_message = "LOG-INV-7: daily_quota_gb must be -1 (unlimited) or a positive integer. Got: ${var.daily_quota_gb}."
  }
}

variable "workspace_key" {
  description = "Internal naming-engine key for the workspace entry. Default \"central\" (one workspace per stack instance)."
  type        = string
  default     = "central"

  validation {
    condition     = can(regex("^[a-z0-9]{1,16}$", var.workspace_key))
    error_message = "workspace_key must match ^[a-z0-9]{1,16}$ (engine services[*].key regex)."
  }
}
