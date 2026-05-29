# T029 - Hub role requires bastion subnet (VNET-INV-10).

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
    "development"   = "10.240.4.0/26"
    "firewall"      = "10.240.5.0/26"
    "firewall-mgmt" = "10.240.5.64/26"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "bastion_required_on_hub" {
  command = plan
  expect_failures = [
    var.subnets,
  ]
}
