# Consumed 006-services remote state. Always read — this engine exists only to
# grant roles over the resources that stack produced. Outputs consumed:
#   naming            => map(canonical_name => { service_type, service_purpose, ... })
#   resource_ids      => map(canonical_name => Azure resource id)
#   resource_group_id => Azure resource id of the services svc RG
data "terraform_remote_state" "services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.services_state_backend.resource_group_name
    storage_account_name = var.services_state_backend.storage_account_name
    container_name       = var.services_state_backend.container_name
    key                  = var.services_state_backend.key
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}
