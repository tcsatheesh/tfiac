###############################################################################
# terraform/log-npd/validate.tf
###############################################################################

check "subscription_pinned" {
  assert {
    condition = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = format(
      "subscription_id mismatch: var.subscription_id=%q but provider is authenticated against %q. Refusing to plan the npd-hub log stack against the wrong subscription.",
      var.subscription_id,
      data.azurerm_client_config.current.subscription_id,
    )
  }
}
