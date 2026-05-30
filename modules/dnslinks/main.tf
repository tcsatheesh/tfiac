# modules/dnslinks/main.tf
#
# Emits one `azurerm_private_dns_zone_virtual_network_link` per private
# DNS zone supplied by the caller. Bare resource (no AVM wrapper) per
# Constitution IX fallback — see README.md "Why bare resource".
#
# Multi-subscription evolution path (FR-214, C16.4, plan §3):
#   * v1: vnet and DNS share subscription 883c9081-..., so the root
#     stack passes `providers = { azurerm.dns = azurerm }` and the
#     `provider = azurerm.dns` selector below is a no-op.
#   * vN: when zones move to a separate subscription, the root stack
#     re-binds the alias to a properly configured azurerm provider —
#     zero submodule change.
#
# Why derive name + RG from the zone id instead of taking them as
# separate inputs: the DNS stack's `zone_ids` output values are
# fully-qualified Azure resource ids of the shape
#   /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/<fqdn>
# so the FQDN (== `private_dns_zone_name`) and the owning RG are both
# encoded in the id. Extracting them here keeps the variable surface
# minimal and avoids forcing the caller to thread three parallel maps.

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.zone_ids

  provider = azurerm.dns

  name                  = "vnetlink-${var.vnet_name}"
  resource_group_name   = regex("/resourceGroups/([^/]+)/", each.value)[0]
  private_dns_zone_name = regex("/privateDnsZones/([^/]+)$", each.value)[0]
  virtual_network_id    = var.vnet_id

  # Hard-coded `false` (NOT a variable) per FR-212 / C16.2 and plan §9:
  # enabling auto-registration on a privatelink.* zone would register
  # VM hostnames into the wrong namespace and cause subtle resolution
  # bugs. NEVER expose this as a caller-tunable input.
  registration_enabled = false

  tags = var.tags
}
