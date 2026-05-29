# T032 - Empty address_space rejected (VNET-INV-9).

variables {
  input = {
    tenant        = "hub"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "net"
    repo          = "tcsatheesh/tfiac"
  }
  role          = "hub"
  address_space = []
  subnets = {
    "development"   = "10.240.4.0/26"
    "bastion"       = "10.240.4.192/26"
    "firewall"      = "10.240.5.0/26"
    "firewall-mgmt" = "10.240.5.64/26"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "address_space_empty_rejected" {
  command = plan
  expect_failures = [
    var.address_space,
  ]
}
