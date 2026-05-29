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
