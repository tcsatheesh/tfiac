###############################################################################
# terraform/dns/variables.tf  (feature 002 — replaces legacy variables)
#
# Exactly the EIGHT inputs allowed by FR-014 / input-schema.md. No others.
#
# EXCLUSIVITY (per T017):
#   - typing + region-allowlist + scope-discriminator parse-time validations
#     live here (subscription_id regex, region allowlist, topology/tenant/
#     environment validations)
#   - custom_zones FQDN-regex + de-dup → T028 (Phase 4)
#   - disable_catalogue_zones de-dup → T033 (Phase 5)
#   - disable_catalogue_zones catalogue-membership → root terraform_data
#     `guard_disable_keys_known` precondition in validate.tf (see validate.tf
#     header for why this lives in root, not in the module — FR-018)
#   - custom_zones no-shadow → root terraform_data
#     `guard_custom_zones_no_shadow` precondition in validate.tf (FR-017)
###############################################################################

variable "subscription_id" {
  description = "Azure subscription GUID for the prd hub. Cross-checked by check.subscription_pinned (FR-029)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase GUID."
  }
}

variable "region" {
  description = "Azure region for the per-stack RG. Must be in local.allowed_prd_hub_regions (OQ-003 → A)."
  type        = string

  validation {
    # Day-one allowlist for the prd hub (research § 6). Kept in sync with
    # local.allowed_prd_hub_regions in locals.tf; that local is the
    # canonical list — this validation is a defence-in-depth duplicate so
    # the rejection happens at variable-parse time too.
    condition     = contains(["swedencentral"], var.region)
    error_message = "region must be one of the platform-approved prd-hub regions (day-one: swedencentral)."
  }
}

variable "repo" {
  description = "Source repository identifier; flows into module.naming baseline tags."
  type        = string

  validation {
    condition     = length(var.repo) > 0
    error_message = "repo is required (FR-001 / FR-014)."
  }
}

# ─── env/scope discriminators ────────────────────────────────────────
variable "topology" {
  description = "Topology this DNS stack serves: typically \"hub\"."
  type        = string

  validation {
    condition     = contains(["hub", "spoke"], var.topology)
    error_message = "topology must be \"hub\" or \"spoke\"."
  }
}

variable "tenant" {
  description = "Tenant code (\"hub\" for centralised hub DNS, or spoke code like \"sp01\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.tenant))
    error_message = "tenant must be lowercase alphanumerics."
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

variable "custom_zones" {
  description = "Operator-supplied private DNS zone FQDNs. Module's variable.validation enforces FR-016/FR-019; module's precondition enforces FR-017 (shadowing)."
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
  description = "Catalogue keys to exclude from creation. Catalogue-membership is enforced by the module precondition (T010/T015)."
  type        = list(string)
  default     = []

  validation {
    # FR-019: no duplicates within disable_catalogue_zones.
    condition     = length(var.disable_catalogue_zones) == length(distinct(var.disable_catalogue_zones))
    error_message = "disable_catalogue_zones contains duplicate entries (FR-019)."
  }
}
