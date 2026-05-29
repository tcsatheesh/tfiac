# T028 - US1 positive baseline for hub role. Asserts vnet canonical name
# matches the committed snapshot fixture.

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

run "vnet_name_matches_snapshot_hub" {
  command = plan

  assert {
    condition     = jsondecode(file("${path.module}/tests/fixtures/vnet_name_snapshot_hub.json")) == output.vnet_name
    error_message = "vnet_name (hub) diverges from vnet_name_snapshot_hub.json. Regenerate per tests/fixtures/README.md if intentional."
  }

  assert {
    condition     = replace(jsondecode(file("${path.module}/tests/fixtures/rg_name_snapshot.json")), "<tenant>", "hub") == output.resource_group_name
    error_message = "resource_group_name (hub) diverges from rg_name_snapshot.json."
  }

  assert {
    condition     = output.route_table_name == "rt-net-shd-hub-npd-swc-001"
    error_message = "route_table_name (hub) diverges from expected canonical."
  }
}
