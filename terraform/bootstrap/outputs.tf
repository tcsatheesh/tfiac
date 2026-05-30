output "resource_group_name" {
  description = "RG holding the state SA."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "RG resource id."
  value       = azurerm_resource_group.this.id
}

output "storage_account_name" {
  description = "State SA canonical name. Feed into variables/backend.hcl."
  value       = azurerm_storage_account.this.name
}

output "storage_account_id" {
  description = "State SA resource id."
  value       = azurerm_storage_account.this.id
}

output "container_name" {
  description = "Blob container name (always \"tfstate\")."
  value       = azurerm_storage_container.tfstate.name
}

output "private_endpoint_id" {
  description = "Private endpoint resource id."
  value       = azurerm_private_endpoint.sa.id
}

output "private_endpoint_ip" {
  description = "Private endpoint NIC private IP."
  value       = azurerm_private_endpoint.sa.private_service_connection[0].private_ip_address
}

output "private_dns_a_record_fqdn" {
  description = "FQDN of the A-record in privatelink.blob.core.windows.net."
  value       = format("%s.%s", local.sa_canonical_name, local.blob_zone_name)
}

output "backend_hcl_snippet" {
  description = "Drop-in replacement for variables/backend.hcl. The `key` is still supplied per-stack at init time."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.this.name}"
    storage_account_name = "${azurerm_storage_account.this.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    use_azuread_auth     = true
    subscription_id      = "${var.subscription_id}"
  EOT
}
