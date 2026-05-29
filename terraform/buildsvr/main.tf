data "azurerm_client_config" "current" {}

# BLD-INV-3: provider-bound subscription MUST match var.subscription_id.
check "subscription_pinned" {
  assert {
    condition = data.azurerm_client_config.current.subscription_id == var.subscription_id
    error_message = format(
      "BLD-INV-3: provider-bound subscription (%s) does not match var.subscription_id (%s).",
      data.azurerm_client_config.current.subscription_id,
      var.subscription_id,
    )
  }
}

# Cross-variable invariant: in production both state backends must be supplied
# unless overrides are used. Surfaces a clean error at plan time.
check "remote_state_inputs_present" {
  assert {
    condition     = (var.vnet_state_backend != null || var.vnet_state_override != null)
    error_message = "vnet_state_backend (production) or vnet_state_override (test) must be supplied."
  }
  assert {
    condition     = (var.log_state_backend != null || var.log_state_override != null)
    error_message = "log_state_backend (production) or log_state_override (test) must be supplied."
  }
}

data "terraform_remote_state" "vnet" {
  count   = var.vnet_state_override == null && var.vnet_state_backend != null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.vnet_state_backend.resource_group_name
    storage_account_name = var.vnet_state_backend.storage_account_name
    container_name       = var.vnet_state_backend.container_name
    key                  = var.vnet_state_backend.key
    use_azuread_auth     = true
    subscription_id      = try(var.vnet_state_backend.subscription_id, null)
  }
}

data "terraform_remote_state" "log" {
  count   = var.log_state_override == null && var.log_state_backend != null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.log_state_backend.resource_group_name
    storage_account_name = var.log_state_backend.storage_account_name
    container_name       = var.log_state_backend.container_name
    key                  = var.log_state_backend.key
    use_azuread_auth     = true
    subscription_id      = try(var.log_state_backend.subscription_id, null)
  }
}

locals {
  subnet_resource_id = (
    var.vnet_state_override != null
    ? var.vnet_state_override.subnet_resource_id
    : data.terraform_remote_state.vnet[0].outputs.subnets["buildsvr"].id
  )

  log_workspace_resource_id = (
    var.log_state_override != null
    ? var.log_state_override.workspace_resource_id
    : data.terraform_remote_state.log[0].outputs.workspace_resource_id
  )
}

module "buildsvr" {
  source = "../../modules/buildsvr"

  input                     = local.naming_input
  subnet_resource_id        = local.subnet_resource_id
  log_workspace_resource_id = local.log_workspace_resource_id

  vm_sku                 = var.vm_sku
  zone                   = var.zone
  source_image_reference = var.source_image_reference
  admin_username         = var.admin_username
  admin_ssh_public_key   = var.admin_ssh_public_key

  os_disk_size_gb   = var.os_disk_size_gb
  data_disk_size_gb = var.data_disk_size_gb

  github_runner_url     = var.github_runner_url
  github_runner_token   = var.github_runner_token
  runner_labels         = var.runner_labels
  github_runner_version = var.github_runner_version

  identity_role_assignments = local.identity_role_assignments
}
