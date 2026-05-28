mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

run "disallowed_region_rejected" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    region          = "eastus"
    repo            = "tcsatheesh/tfiac"
    role            = "hub"
    topology        = "hub"
    tenant          = "hub"
    environment     = "npd"
    address_space   = ["10.240.4.0/23"]
    subnets         = { "bastion" = "10.240.4.192/28", "firewall" = "10.240.5.0/26", "firewall-mgmt" = "10.240.5.64/26" }
  }

  expect_failures = [
    var.region,
  ]
}
