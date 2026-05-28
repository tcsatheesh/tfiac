###############################################################################
# terraform/vnet/variables.tf  (feature 004 — role-driven hub | spoke stack)
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
  description = "Azure region. Day-one allowlist: swedencentral."
  type        = string
  validation {
    condition     = contains(["swedencentral"], var.region)
    error_message = "region must be one of the platform-approved regions (day-one: swedencentral)."
  }
}

variable "repo" {
  type = string
  validation {
    condition     = length(var.repo) > 0
    error_message = "repo is required."
  }
}

# ─── role / env / scope discriminators ───────────────────────────────────────

variable "role" {
  description = "Which side of the hub-spoke topology this plan creates. \"hub\" provisions vnet + NSGs + bastion + firewall + default route; \"spoke\" provisions vnet + NSGs + spoke->hub peering + default route via hub firewall."
  type        = string
  validation {
    condition     = contains(["hub", "spoke"], var.role)
    error_message = "role must be \"hub\" or \"spoke\"."
  }
}

variable "topology" {
  description = "Topology label fed into baseline tags (usually equal to role)."
  type        = string
  validation {
    condition     = contains(["hub", "spoke"], var.topology)
    error_message = "topology must be \"hub\" or \"spoke\"."
  }
}

variable "tenant" {
  description = "Tenant code: \"hub\" for centralised hub, otherwise the spoke code (e.g. \"sp01\")."
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

# ─── network shape (per-deployment) ──────────────────────────────────────────

variable "address_space" {
  description = "vnet address space prefix list."
  type        = list(string)
  validation {
    condition     = length(var.address_space) >= 1
    error_message = "address_space must contain at least one CIDR."
  }
}

variable "subnets" {
  description = "Map of subnet purpose -> CIDR. Keys feed the naming engine (snet-<purpose>-...). For hub, must include the canonical purposes used by enabled add-ons (e.g. \"bastion\", \"firewall\", \"firewall-mgmt\" when role=hub)."
  type        = map(string)
}

# ─── hub-only ────────────────────────────────────────────────────────────────

variable "spoke_peerings" {
  description = <<-EOT
  (role=hub only) Spokes this hub will peer to (hub-side leg only). The
  reciprocal spoke-side leg lives in each spoke's own plan.

  Add an entry HERE whenever a new spoke plan is created — without it,
  the spoke's spoke->hub peer will stay in "Initiated" state because
  the hub side is missing. The spoke's `check.hub_peering_registered`
  block emits a Terraform warning when this map is missing the spoke.

  Key = friendly id (e.g. "sp01-npd"). Used only as the peer name suffix.
  EOT
  type = map(object({
    remote_vnet_id   = string
    remote_vnet_name = string
  }))
  default = {}
}

# ─── spoke-only ──────────────────────────────────────────────────────────────

variable "hub_state_backend" {
  description = <<-EOT
  (role=spoke only) azurerm backend config locating the HUB vnet plan's
  remote state. The spoke reads vnet_id + firewall_private_ip +
  peered_spoke_vnet_names from those outputs. Leave null when role=hub
  or when the test override variables below are supplied.
  EOT
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })
  default = null
}

variable "hub_vnet_id_override" {
  description = "(test seam) When set, skips terraform_remote_state and uses this value as the hub vnet id."
  type        = string
  default     = ""
}

variable "hub_firewall_private_ip_override" {
  description = "(test seam) When set, skips terraform_remote_state and uses this value as the hub firewall private IP."
  type        = string
  default     = ""
}

variable "hub_peered_spoke_vnet_names_override" {
  description = "(test seam) When set, skips terraform_remote_state and uses this list for check.hub_peering_registered."
  type        = list(string)
  default     = []
}
