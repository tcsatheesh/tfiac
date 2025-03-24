resource "azurerm_role_assignment" "container_registry_acrpull" {
  provider             = azurerm.services
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = var.function_app_managed_identity_id
}