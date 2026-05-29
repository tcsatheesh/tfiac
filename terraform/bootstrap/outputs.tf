###############################################################################
# terraform/bootstrap/outputs.tf
#
# Emit the values every other stack needs for `-backend-config`. Paste these
# into variables/backend.hcl (or pass on the CLI).
###############################################################################

output "resource_group_name" {
  description = "Resource group hosting the tfstate storage account."
  value       = azurerm_resource_group.this.name
}

output "storage_account_name" {
  description = "Storage account name for tfstate."
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  description = "Container name for tfstate blobs."
  value       = azurerm_storage_container.tfstate.name
}

output "backend_config_snippet" {
  description = "Ready-to-paste -backend-config block."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.this.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    use_azuread_auth     = true
  EOT
}
