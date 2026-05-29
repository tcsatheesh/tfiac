# Reference variables + 5 mock_provider blocks every test in this directory
# expects. terraform test does NOT auto-share variables/mock_provider blocks
# across files, so each test file declares its own copies. Kept here as
# living documentation of the canonical baseline.

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
    "development"    = "10.240.4.0/26"
    "pre-production" = "10.240.4.64/26"
    "api-management" = "10.240.4.144/28"
    "buildsvr"       = "10.240.4.160/28"
    "bastion"        = "10.240.4.192/26"
    "firewall"       = "10.240.5.0/26"
    "firewall-mgmt"  = "10.240.5.64/26"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "baseline_validate" {
  command = plan
}
