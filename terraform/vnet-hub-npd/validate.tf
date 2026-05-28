check "subscription_pinned" {
  assert {
    condition = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = format(
      "subscription_id mismatch: var.subscription_id=%q but provider authenticated against %q. Refusing to plan vnet-hub-npd against the wrong subscription.",
      var.subscription_id,
      data.azurerm_client_config.current.subscription_id,
    )
  }
}
