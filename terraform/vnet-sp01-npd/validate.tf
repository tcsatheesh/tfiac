check "subscription_pinned" {
  assert {
    condition = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = format(
      "subscription_id mismatch: var.subscription_id=%q but provider authenticated against %q. Refusing to plan vnet-sp01-npd against the wrong subscription.",
      var.subscription_id,
      data.azurerm_client_config.current.subscription_id,
    )
  }
}

# Warning-only (check block, not variable validation). Reminds the operator
# that after creating / renaming this spoke the HUB stack must add an entry
# to var.spoke_peerings = { "sp01-npd" = { remote_vnet_id, remote_vnet_name } }
# and be re-applied — otherwise the hub-side peering leg is missing and
# spoke<->hub traffic stays in "Initiated" / "Disconnected" state.
check "hub_peering_registered" {
  assert {
    condition = contains(local.hub_peered_spoke_vnet_names, module.network.vnet_name)
    error_message = format(
      "REMINDER: hub vnet does not list %q in its spoke_peerings map. Add an entry to terraform/vnet-hub-npd/terraform.tfvars (or locals) for this spoke and run `terraform apply` on the hub. Until you do, the spoke<->hub peering will only have one leg and traffic will not flow. (Current hub-registered spokes: %s)",
      module.network.vnet_name,
      length(local.hub_peered_spoke_vnet_names) == 0 ? "<none>" : join(", ", local.hub_peered_spoke_vnet_names),
    )
  }
}
