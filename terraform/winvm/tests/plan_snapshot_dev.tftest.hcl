# Root-stack snapshot for sp01/dev (jump box).

variables {
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  region              = "swc"
  repo                = "tcsatheesh/tfiac"
  tenant              = "sp01"
  environment         = "dev"
  usecase             = "uc1"
  stack_purpose       = "svc"
  resource_group_name = "rg-svc-uc1-sp01-dev-swc-001"
  subnet_role         = "development"
  key_vault_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.KeyVault/vaults/kvfdyuc1sp01devswc001"

  vnet_state_override = {
    subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-sp01-npd-swc-001/subnets/snet-dev-vnet-net-shd-sp01-npd-swc-001"
  }
  log_state_override = {
    workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
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

run "snapshot_dev" {
  command = plan

  assert {
    condition     = "vm-jmp-uc1-sp01-dev-swc-001" == output.vm_name
    error_message = "Root-stack vm_name (dev) diverges from committed snapshot."
  }

  assert {
    condition     = "rg-svc-uc1-sp01-dev-swc-001" == output.resource_group_name
    error_message = "Root-stack resource_group_name must echo the existing RG input."
  }
}
