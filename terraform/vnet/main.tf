data "azurerm_client_config" "current" {}

# VNET-INV-4: the bound subscription MUST match the declared subscription_id.
check "subscription_match" {
  assert {
    condition = data.azurerm_client_config.current.subscription_id == var.subscription_id
    error_message = format(
      "VNET-INV-4: provider-bound subscription (%s) does not match var.subscription_id (%s).",
      data.azurerm_client_config.current.subscription_id,
      var.subscription_id,
    )
  }
}

# Spoke-only: pull hub vnet attributes from remote state UNLESS
# var.hub_state_override is supplied (terraform-test path).
data "terraform_remote_state" "hub" {
  count   = var.role == "spoke" && var.hub_state_override == null ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = try(var.hub_state_backend.resource_group_name, "")
    storage_account_name = try(var.hub_state_backend.storage_account_name, "")
    container_name       = try(var.hub_state_backend.container_name, "")
    key                  = try(var.hub_state_backend.key, "")
    use_azuread_auth     = true
    subscription_id      = try(var.hub_state_backend.subscription_id, null)
  }
}

locals {
  hub_outputs = (
    var.role != "spoke"
    ? null
    : (
      var.hub_state_override != null
      ? var.hub_state_override
      : {
        vnet_id             = data.terraform_remote_state.hub[0].outputs.vnet_id
        vnet_name           = data.terraform_remote_state.hub[0].outputs.vnet_name
        resource_group_name = data.terraform_remote_state.hub[0].outputs.resource_group_name
        firewall_private_ip = data.terraform_remote_state.hub[0].outputs.firewall_private_ip
      }
    )
  )
}

module "network" {
  source = "../../modules/network"

  input         = local.naming_input
  role          = var.role
  address_space = var.address_space
  subnets       = var.subnets

  extra_nsg_rules = var.extra_nsg_rules

  firewall_sku_tier        = var.firewall_sku_tier
  enable_hub_default_route = var.enable_hub_default_route
  enable_hub_firewall      = var.enable_hub_firewall

  hub_vnet_id             = var.role == "spoke" ? local.hub_outputs.vnet_id : null
  hub_firewall_private_ip = var.role == "spoke" ? local.hub_outputs.firewall_private_ip : null
  hub_subscription_id     = var.role == "spoke" ? try(var.hub_state_backend.subscription_id, null) : null
}

# Spoke-only: bidirectional peering with the hub (Constitution IX exception).
module "peering" {
  source = "../../modules/network/peering"
  count  = var.role == "spoke" ? 1 : 0

  providers = {
    azurerm.this = azurerm
    azurerm.hub  = azurerm.hub
  }

  spoke_vnet_id             = module.network.vnet_id
  spoke_vnet_name           = module.network.vnet_name
  spoke_resource_group_name = module.network.resource_group_name

  hub_vnet_id             = local.hub_outputs.vnet_id
  hub_vnet_name           = local.hub_outputs.vnet_name
  hub_resource_group_name = local.hub_outputs.resource_group_name
}
