# Negative: a reserved Windows admin username is rejected by validation.

variables {
  input = {
    tenant        = "sp01"
    environment   = "dev"
    region        = "swc"
    usecase       = "uc1"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }

  resource_group_name       = "rg-svc-uc1-sp01-dev-swc-001"
  subnet_resource_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-sp01-npd-swc-001/subnets/snet-dev-vnet-net-shd-sp01-npd-swc-001"
  log_workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  key_vault_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.KeyVault/vaults/kvfdyuc1sp01devswc001"
  admin_username            = "administrator"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "reserved_admin_username_rejected" {
  command         = plan
  expect_failures = [var.admin_username]
}
