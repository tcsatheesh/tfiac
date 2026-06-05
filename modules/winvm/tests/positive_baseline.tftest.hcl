# US1: engine emits the locked-in canonical names for a representative tuple
# (sp01/dev jump box) and the derived secret/nic/disk names.

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
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "snapshot_dev" {
  command = plan

  assert {
    condition     = output.vm_name == "vm-jmp-uc1-sp01-dev-swc-001"
    error_message = "vm_name diverges from committed WIN-INV-8 snapshot."
  }

  assert {
    condition     = output.nic_name == "nic-vm-jmp-uc1-sp01-dev-swc-001"
    error_message = "nic_name derivation drifted (WIN-INV-9)."
  }

  assert {
    condition     = output.os_disk_name == "osdisk-vm-jmp-uc1-sp01-dev-swc-001"
    error_message = "os_disk_name derivation drifted (WIN-INV-9)."
  }

  assert {
    condition     = output.resource_group_name == "rg-svc-uc1-sp01-dev-swc-001"
    error_message = "resource_group_name must echo the existing RG name input."
  }
}
