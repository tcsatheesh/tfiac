variable "vnet_id" {
  description = "Azure resource id of the consuming virtual network. Passed by the root stack as module.network.vnet_id (FR-219, C16.9)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.vnet_id))
    error_message = "vnet_id must be a fully-qualified Microsoft.Network/virtualNetworks resource id."
  }
}

variable "vnet_name" {
  description = "Engine-emitted canonical vnet name. Used to derive the per-zone link name (\"vnetlink-$${var.vnet_name}\") per FR-213 / C16.3."
  type        = string

  validation {
    condition     = length(var.vnet_name) > 0 && length(var.vnet_name) <= 64
    error_message = "vnet_name must be a non-empty string <= 64 chars (Azure link name max is 80; \"vnetlink-\" prefix adds 9)."
  }
}

variable "zone_ids" {
  description = "Map of {catalogue_key|custom_fqdn} => private DNS zone resource id, sourced from the DNS stack's `zone_ids` output (FR-211, FR-214, FR-219, C16.4)."
  type        = map(string)

  validation {
    condition     = alltrue([for v in values(var.zone_ids) : can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+$", v))])
    error_message = "Every zone_ids value must be a fully-qualified Microsoft.Network/privateDnsZones resource id."
  }
}

variable "tags" {
  description = "Tags applied to every vnet-link resource. Root stack passes module.network.vnet_tags so link provenance matches the consuming vnet."
  type        = map(string)
  default     = {}
}

variable "dns_subscription_id" {
  description = "Documentation-only: subscription id that owns the parent DNS zones. NOT used for provider configuration (providers cannot be configured from variables — see providers.tf and plan §3). Optional; null in v1 because vnet and DNS share a subscription."
  type        = string
  default     = null
}
