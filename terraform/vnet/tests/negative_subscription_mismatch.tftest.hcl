mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      tenant_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      object_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      client_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
    }
  }
}

run "subscription_mismatch_fails" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    region          = "swedencentral"
    repo            = "_github_org/_github_repo"
    role            = "hub"
    topology        = "hub"
    tenant          = "hub"
    environment     = "npd"
    address_space   = ["10.240.4.0/23"]
    subnets         = { "bastion" = "10.240.4.192/28", "firewall" = "10.240.5.0/26", "firewall-mgmt" = "10.240.5.64/26" }
  }

  expect_failures = [
    check.subscription_pinned,
  ]
}
