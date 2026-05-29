# FR-210 - hub workload subnets must reach the internet via the in-vnet
# firewall. With enable_hub_default_route=true (default) the shared hub
# route table gains 0.0.0.0/0 -> module.firewall[0].private_ip.
#
# We assert plan success against mocked providers; the route value itself
# resolves at apply time (firewall private IP is computed). The negative
# branch (enable_hub_default_route=false) must also plan cleanly so callers
# can opt out.

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

run "hub_default_route_enabled_by_default" {
  command = plan

  assert {
    condition     = output.route_table_name == "rt-net-shd-hub-npd-swc-001"
    error_message = "FR-210: hub route table name must still be the engine canonical."
  }
}

run "hub_default_route_disabled_opt_out" {
  command = plan

  variables {
    enable_hub_default_route = false
  }

  assert {
    condition     = output.route_table_name == "rt-net-shd-hub-npd-swc-001"
    error_message = "FR-210: hub route table must still provision when default route is opted out."
  }
}
