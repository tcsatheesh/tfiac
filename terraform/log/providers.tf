# T004 - root-stack provider blocks.
# Constitution VI: provider blocks only exist at the root stack level.
provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}
