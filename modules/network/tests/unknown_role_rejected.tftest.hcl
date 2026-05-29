# T031 - Unknown subnet role rejected (VNET-INV-5).

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
  address_space = ["10.240.4.0/23"]
  subnets = {
    "no-such-role"  = "10.240.4.0/26"
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

run "unknown_role_rejected" {
  command = plan
  expect_failures = [
    var.subnets,
  ]
}
