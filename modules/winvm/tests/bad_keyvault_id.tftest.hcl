# Negative: a malformed Key Vault id is rejected by variable validation.

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
  key_vault_id              = "not-a-valid-key-vault-id"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "bad_key_vault_id_rejected" {
  command         = plan
  expect_failures = [var.key_vault_id]
}
