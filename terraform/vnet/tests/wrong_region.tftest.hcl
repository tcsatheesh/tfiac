# T033 - region must be "swc".

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  repo            = "tcsatheesh/tfiac"
  region          = "uks"
  tenant          = "hub"
  environment     = "npd"
  role            = "hub"
  usecase         = "shd"
  address_space   = ["10.240.4.0/23"]
  subnets = {
    "development"   = "10.240.4.0/26"
    "bastion"       = "10.240.4.192/26"
    "firewall"      = "10.240.5.0/26"
    "firewall-mgmt" = "10.240.5.64/26"
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
mock_provider "azurerm" { alias = "hub" }
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "wrong_region" {
  command = plan
  expect_failures = [
    var.region,
  ]
}
