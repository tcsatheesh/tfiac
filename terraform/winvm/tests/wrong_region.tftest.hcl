# WIN-INV-1: a non-swc region must be rejected by variable validation.

variables {
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  region              = "weu"
  repo                = "tcsatheesh/tfiac"
  tenant              = "sp01"
  environment         = "dev"
  usecase             = "uc1"
  stack_purpose       = "svc"
  resource_group_name = "rg-svc-uc1-sp01-dev-swc-001"
  subnet_role         = "development"
  key_vault_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.KeyVault/vaults/kvfdyuc1sp01devswc001"

  vnet_state_override = {
    subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/v/subnets/s"
  }
  log_state_override = {
    workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/w"
  }
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "wrong_region_rejected" {
  command         = plan
  expect_failures = [var.region]
}
