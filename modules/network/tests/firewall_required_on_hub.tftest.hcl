# T030 - Hub role requires firewall + firewall-mgmt subnets (VNET-INV-10).

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
    "development" = "10.240.4.0/26"
    "bastion"     = "10.240.4.192/26"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "firewall_required_on_hub" {
  command = plan
  expect_failures = [
    var.subnets,
  ]
}
