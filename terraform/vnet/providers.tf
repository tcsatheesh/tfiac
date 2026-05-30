# The wrapper module already passes the spoke vnet's provider as the
# default. For the spoke role, the peering submodule also needs an
# alias to the HUB subscription so it can create the hub-side peering
# from this stack — see modules/network/peering/README.md for the
# Constitution IX rationale.

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "azurerm" {
  alias           = "hub"
  subscription_id = coalesce(try(var.hub_state_backend.subscription_id, null), var.subscription_id)
  features {}
}

# `azurerm.dns` — forward-compat alias for the subscription that owns
# the parent private DNS zones (FR-214, C16.4, plan §3). In v1 the
# DNS subscription equals the vnet subscription so this resolves to
# the same target as the default provider; the alias exists so the
# multi-subscription evolution path is a one-line root-stack change
# with zero submodule churn.
provider "azurerm" {
  alias           = "dns"
  subscription_id = var.dns_state_backend.subscription_id
  features {}
}
