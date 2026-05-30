data "azurerm_client_config" "current" {}

# BOOT-INV-1: provider-bound subscription MUST match var.subscription_id.
check "subscription_pinned" {
  assert {
    condition = data.azurerm_client_config.current.subscription_id == var.subscription_id
    error_message = format(
      "BOOT-INV-1: provider-bound subscription (%s) does not match var.subscription_id (%s). Run `az account set --subscription <id>` before plan/apply.",
      data.azurerm_client_config.current.subscription_id,
      var.subscription_id,
    )
  }
}

# Legacy state, read at bootstrap-apply time only. The legacy SA firewall
# must be opened to the operator IP for the duration of `terraform init`
# / `terraform plan` / `terraform apply` (see README, plan §8 step 2).
data "terraform_remote_state" "vnet" {
  count   = var.remote_state_override == null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.legacy_state_backend.resource_group_name
    storage_account_name = var.legacy_state_backend.storage_account_name
    container_name       = var.legacy_state_backend.container_name
    key                  = var.legacy_state_backend.vnet_key
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}

data "terraform_remote_state" "dns" {
  count   = var.remote_state_override == null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.legacy_state_backend.resource_group_name
    storage_account_name = var.legacy_state_backend.storage_account_name
    container_name       = var.legacy_state_backend.container_name
    key                  = var.legacy_state_backend.dns_key
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}

data "terraform_remote_state" "buildsvr" {
  count   = var.build_vm_override == null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.legacy_state_backend.resource_group_name
    storage_account_name = var.legacy_state_backend.storage_account_name
    container_name       = var.legacy_state_backend.container_name
    key                  = var.legacy_state_backend.buildsvr_key
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}
