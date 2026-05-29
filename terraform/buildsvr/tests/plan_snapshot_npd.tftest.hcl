# Root-stack-level snapshot for npd.

variables {
  subscription_id      = "00000000-0000-0000-0000-000000000000"
  region               = "swc"
  repo                 = "tcsatheesh/tfiac"
  tenant               = "hub"
  environment          = "npd"
  admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGGUswYR/ktYuk34UrRqPpyok4lValKUn6DeTfydqMwF test@buildsvr"

  vnet_state_override = {
    subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001/subnets/snet-bld-vnet-net-shd-hub-npd-swc-001"
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
mock_provider "tls" {}

run "snapshot_npd" {
  command = plan

  assert {
    condition     = "vm-bld-shd-hub-npd-swc-001" == output.vm_name
    error_message = "Root-stack vm_name (npd) diverges from committed snapshot."
  }

  assert {
    condition     = "rg-bld-shd-hub-npd-swc-001" == output.resource_group_name
    error_message = "Root-stack resource_group_name (npd) diverges from committed snapshot."
  }

  assert {
    condition     = "unregistered" == output.runner_status
    error_message = "Default github_runner_token (empty) must yield runner_status=unregistered."
  }
}
