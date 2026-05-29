# Root-stack inputs. Mirror modules/dnszones/variables.tf (1:1) plus the
# scope-hardpin validations DNS-INV-9 that distinguish the prd-hub-only stack
# (FR-001) from any future reuse of the wrapper module.

variable "subscription_id" {
  description = "Azure subscription ID. Cross-checked at plan time against data.azurerm_client_config (FR-029)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }
}

variable "region" {
  description = "Azure region short code. Must be 'swc' (swedencentral) for the prd-hub DNS stack."
  type        = string

  validation {
    condition     = contains(["swc"], var.region)
    error_message = "DNS-INV-9 / FR-001: region must be \"swc\" for the prd-hub DNS stack. Got: ${var.region}."
  }
}

variable "repo" {
  description = "Source repository slug for the managed_by trail (FR-014)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.repo)) && length(var.repo) <= 256
    error_message = "repo must match ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ and be <=256 chars."
  }
}

variable "topology" {
  description = "Topology discriminator. Must be 'hub' for the DNS stack (FR-001)."
  type        = string

  validation {
    condition     = contains(["hub"], var.topology)
    error_message = "DNS-INV-9 / FR-001: topology must be \"hub\". Got: ${var.topology}."
  }
}

variable "tenant" {
  description = "Tenant identifier. Must be 'hub' for the DNS stack (FR-001)."
  type        = string

  validation {
    condition     = contains(["hub"], var.tenant)
    error_message = "DNS-INV-9 / FR-001: tenant must be \"hub\". Got: ${var.tenant}."
  }
}

variable "environment" {
  description = "Environment short code. Must be 'prd' for the DNS stack (FR-001)."
  type        = string

  validation {
    condition     = contains(["prd"], var.environment)
    error_message = "DNS-INV-9 / FR-001: environment must be \"prd\". Got: ${var.environment}."
  }
}

variable "custom_zones" {
  description = "Bespoke FQDNs to provision alongside the catalogue (FR-016, FR-017)."
  type        = list(string)
  default     = []
}

variable "disable_catalogue_zones" {
  description = "Catalogue keys to omit from the effective zone set (FR-018)."
  type        = list(string)
  default     = []
}
