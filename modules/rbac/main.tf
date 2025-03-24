resource "azurerm_role_assignment" "container_registry_acrpull" {
  provider             = azurerm.services
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_linux_function_app.fnapp[0].identity[0].principal_id
}