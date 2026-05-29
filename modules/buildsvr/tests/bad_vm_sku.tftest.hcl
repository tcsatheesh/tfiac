# BLD-INV-10: vm_sku must match ^Standard_[A-Za-z0-9_]+$.

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
  vm_sku                    = "standard-d4s-v5"
  github_runner_token       = ""
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "tls" {}

run "bad_vm_sku_rejected" {
  command = plan

  expect_failures = [
    var.vm_sku,
  ]
}
