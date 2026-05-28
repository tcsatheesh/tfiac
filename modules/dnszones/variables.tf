# modules/dnszones/variables.tf
# Input contract per specs/002-private-dns-zones/contracts/input-schema.md.

variable "naming" {
  description = "Passthrough of module.naming.names (canonical_name → record). Typed loosely as the engine record schema evolves."
  type        = map(any)
}

variable "region" {
  description = "Azure region (e.g. \"uksouth\"). Used as azurerm_resource_group.location."
  type        = string
}

variable "region_code" {
  description = "Short engine-mapped region code (e.g. \"uks\" for \"uksouth\"). Supplied by the root stack from module.naming's region_codes catalogue (or a static fallback map) to avoid re-deriving inside this module."
  type        = string
}

variable "custom_zones" {
  description = "Operator-supplied private DNS zone FQDNs. Each entry becomes both a for_each key and the azurerm_private_dns_zone.name argument (bypasses engine naming per OQ-001 → B)."
  type        = list(string)
  default     = []

  validation {
    # FR-016: each entry must be a valid lowercase DNS FQDN, ≥ 2 labels, ≤ 253 chars.
    condition = alltrue([
      for e in var.custom_zones : (
        length(e) <= 253
        && length(split(".", e)) >= 2
        && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", e))
      )
    ])
    error_message = "custom_zones entries must be lowercase DNS FQDNs with ≥ 2 labels, each label ≤ 63 chars, total ≤ 253 chars (FR-016)."
  }

  validation {
    # FR-019: no duplicates within custom_zones.
    condition     = length(var.custom_zones) == length(distinct(var.custom_zones))
    error_message = "custom_zones contains duplicate entries (FR-019)."
  }
}

variable "disable_catalogue_zones" {
  description = "Catalogue KEYS (not FQDNs) to exclude from creation. Catalogue-membership is enforced by a precondition on azurerm_resource_group.this (T010 primary path)."
  type        = list(string)
  default     = []

  validation {
    # FR-019: no duplicates within disable_catalogue_zones.
    condition     = length(var.disable_catalogue_zones) == length(distinct(var.disable_catalogue_zones))
    error_message = "disable_catalogue_zones contains duplicate entries (FR-019)."
  }
}

variable "input" {
  description = "Engine input object — passed through for the module-internal baseline-tag derivation (Constitution VIII). Must conform to modules/naming/variables.tf:variable.input."
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
