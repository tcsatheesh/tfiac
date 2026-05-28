variable "subscription_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase GUID."
  }
}

variable "region" {
  type = string
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

variable "spoke_peerings" {
  description = <<-EOT
  Spokes this hub will peer to (hub-side leg only). The reciprocal
  spoke-side leg lives in each spoke's own stack.

  Add an entry HERE whenever a new spoke stack is created — without it,
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
