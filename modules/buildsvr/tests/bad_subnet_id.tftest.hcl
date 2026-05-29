# Variable validation rejects malformed subnet_resource_id.

variables {
  input = {
    tenant        = "hub"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "bld"
    repo          = "tcsatheesh/tfiac"
  }

  subnet_resource_id        = "not-a-resource-id"
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

run "subnet_resource_id_rejected" {
  command = plan

  expect_failures = [
    var.subnet_resource_id,
  ]
}
