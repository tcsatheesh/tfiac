# US1: engine emits the locked-in canonical names for the hub/npd buildsvr.

variables {
  input = {
    tenant        = "hub"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "bld"
    repo          = "tcsatheesh/tfiac"
  }

  subnet_resource_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001/subnets/snet-bld-vnet-net-shd-hub-npd-swc-001"
  log_workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  admin_ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGGUswYR/ktYuk34UrRqPpyok4lValKUn6DeTfydqMwF test@buildsvr"
  github_runner_token       = ""
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "tls" {}

run "snapshot_npd" {
  command = plan

  assert {
    condition     = output.vm_name == "vm-bld-shd-hub-npd-swc-001"
    error_message = "vm_name diverges from committed BLD-INV-8 snapshot."
  }

  assert {
    condition     = output.resource_group_name == "rg-bld-shd-hub-npd-swc-001"
    error_message = "resource_group_name diverges from committed BLD-INV-8 snapshot."
  }

  assert {
    condition     = output.nic_name == "nic-vm-bld-shd-hub-npd-swc-001"
    error_message = "nic_name derivation drifted (BLD-INV-9)."
  }

  assert {
    condition     = output.os_disk_name == "osdisk-vm-bld-shd-hub-npd-swc-001"
    error_message = "os_disk_name derivation drifted (BLD-INV-9)."
  }

  assert {
    condition     = output.data_disk_name == "disk-vm-bld-shd-hub-npd-swc-001-0"
    error_message = "data_disk_name derivation drifted (BLD-INV-9)."
  }

  assert {
    condition     = output.runner_status == "unregistered"
    error_message = "Empty GitHub token must surface runner_status = unregistered."
  }
}
