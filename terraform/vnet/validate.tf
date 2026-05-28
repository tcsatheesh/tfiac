###############################################################################
# terraform/vnet/validate.tf
###############################################################################

check "subscription_pinned" {
  assert {
    condition = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = format(
      "subscription_id mismatch: var.subscription_id=%q but provider authenticated against %q. Refusing to plan against the wrong subscription.",
      var.subscription_id,
      data.azurerm_client_config.current.subscription_id,
    )
  }
}

# Warning-only (spoke role): the HUB stack must register this spoke in its
# var.spoke_peerings map and be re-applied — otherwise the hub-side peering
# leg is missing and spoke<->hub traffic stays in "Initiated" /
# "Disconnected" state.
check "hub_peering_registered" {
  assert {
    condition = !local.is_spoke || contains(local.hub_peered_spokes, module.network.vnet_name)
    error_message = format(
      "REMINDER: hub vnet does not list %q in its spoke_peerings map. Add an entry to the HUB stack's terraform.tfvars (or its remote-state outputs) for this spoke and run `terraform apply` on the hub. Until you do, the spoke<->hub peering will only have one leg and traffic will not flow. (Current hub-registered spokes: %s)",
      module.network.vnet_name,
      length(local.hub_peered_spokes) == 0 ? "<none>" : join(", ", local.hub_peered_spokes),
    )
  }
}
