output "function_app_id" {
  value = azurerm_linux_function_app.fnapp.id
}

output "managed_identity_id" {
  value = azurerm_linux_function_app.fnapp.identity[0].principal_id
}