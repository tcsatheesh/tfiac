###############################################################################
# terraform/dns/variables.tf  (feature 002 — replaces legacy variables)
#
# Exactly the FIVE inputs allowed by FR-014 / input-schema.md. No others.
#
# EXCLUSIVITY (per T017):
#   - typing + region-allowlist live here
#   - custom_zones FQDN-regex + de-dup → T028 (Phase 4)
#   - disable_catalogue_zones de-dup → T033 (Phase 5)
#   - disable_catalogue_zones catalogue-membership → module precondition
#     (modules/dnszones/main.tf — T010/T015)
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

variable "custom_zones" {
  description = "Operator-supplied private DNS zone FQDNs. Module's variable.validation enforces FR-016/FR-019; module's precondition enforces FR-017 (shadowing — added in Phase 4 / T027)."
  type        = list(string)
  default     = []
}

variable "disable_catalogue_zones" {
  description = "Catalogue keys to exclude from creation. Catalogue-membership is enforced by the module precondition (T010/T015). De-dup validation comes in Phase 5 (T033)."
  type        = list(string)
  default     = []
}
