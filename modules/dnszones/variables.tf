# Public inputs to the dnszones wrapper module.
# Mirrors the root-stack FR-014 input set 1:1 so each stack just shapes a single
# object before calling the wrapper. Validation here covers the wrapper-local
# invariants (DNS-INV-4, DNS-INV-6, DNS-INV-7); the cross-stack invariants
# (FR-001 hub/prd/swc, FR-029 subscription match) live at the root stack so
# this module stays reusable should a future spoke-DNS stack ever appear.

variable "subscription_id" {
  description = "Azure subscription ID where the DNS RG and zones land. Root stack cross-checks against data.azurerm_client_config (FR-029)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }
}

variable "region" {
  description = "Azure region short code (FR-014; root stack hard-pins to 'swc')."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.region))
    error_message = "region must match ^[a-z0-9]{3,4}$ (CAF short code)."
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
  description = "Scope discriminator; must be 'hub' for the DNS stack (FR-001)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.topology))
    error_message = "topology must match ^[a-z0-9]{2,8}$."
  }
}

variable "tenant" {
  description = "Tenant identifier (FR-014). DNS stack pins to 'hub' at the root."
  type        = string

  validation {
    condition     = can(regex("^(hub|sp[0-9]{2})$", var.tenant))
    error_message = "tenant must match ^(hub|sp[0-9]{2})$."
  }
}

variable "environment" {
  description = "Environment short code (FR-014). DNS stack pins to 'prd' at the root."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{3}$", var.environment))
    error_message = "environment must match ^[a-z]{3}$."
  }
}

variable "custom_zones" {
  description = "Bespoke FQDNs to provision alongside the catalogue (FR-016, FR-017, FR-019)."
  type        = list(string)
  default     = []

  # DNS-INV-7 (per-element FQDN regex): each label [a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?,
  # at least two labels, total length <= 253.
  validation {
    condition = alltrue([
      for f in var.custom_zones :
      length(f) >= 1
      && length(f) <= 253
      && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)(\\.([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?))+$", f))
    ])
    error_message = "Every custom_zones entry must be a valid lowercase FQDN with >=2 labels (each label [a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?), total <=253 chars (FR-016). Offending entries: ${jsonencode([
      for f in var.custom_zones : f
      if !(length(f) >= 1
        && length(f) <= 253
      && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)(\\.([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?))+$", f)))
    ])}."
  }

  # DNS-INV-4 - duplicates within custom_zones.
  validation {
    condition = length(var.custom_zones) == length(distinct(var.custom_zones))
    error_message = "custom_zones contains duplicate FQDN(s) (FR-019, DNS-INV-4). Offending entries: ${jsonencode([
      for f in distinct(var.custom_zones) : f
      if length([for x in var.custom_zones : x if x == f]) > 1
    ])}."
  }
}

variable "disable_catalogue_zones" {
  description = "Catalogue keys to omit from the effective zone set (FR-018, FR-019)."
  type        = list(string)
  default     = []

  # DNS-INV-6 - duplicates within disable_catalogue_zones.
  validation {
    condition = length(var.disable_catalogue_zones) == length(distinct(var.disable_catalogue_zones))
    error_message = "disable_catalogue_zones contains duplicate key(s) (FR-019, DNS-INV-6). Offending entries: ${jsonencode([
      for k in distinct(var.disable_catalogue_zones) : k
      if length([for x in var.disable_catalogue_zones : x if x == k]) > 1
    ])}."
  }
}
