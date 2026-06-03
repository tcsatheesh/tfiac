# FR-228 / C24 — spoke auto-adapts when the hub firewall is torn down.
#
# Run 1 (hub_firewall_private_ip set): parity. The spoke route table carries
# the 0.0.0.0/0 route, route_table_active is true, and workload subnets attach.
# Run 2 (hub_firewall_private_ip = null): the hub firewall is gone, so the
# spoke emits no default route, route_table_active is false, and NO workload
# subnet attaches the shared route table. The relaxed VNET-INV-spoke
# precondition (C24) still allows the plan with only hub_vnet_id supplied.
#
# Plan-only, fully mocked, -backend=false.

variables {
  input = {
    tenant        = "sp01"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "net"
    repo          = "tcsatheesh/tfiac"
  }
  role                = "spoke"
  address_space       = ["10.240.2.0/24"]
  hub_vnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
  hub_subscription_id = "00000000-0000-0000-0000-000000000001"
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "function-app"   = "10.240.2.144/28"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "spoke_with_hub_firewall_parity" {
  command = plan

  variables {
    hub_firewall_private_ip = "10.240.5.4"
  }

  assert {
    condition     = output.route_table_active == true
    error_message = "FR-228: spoke with a hub firewall IP must have route_table_active == true."
  }

  assert {
    condition     = output.subnet_route_table_attached["development"] == true
    error_message = "FR-228: spoke workload subnet must attach the RT when the hub firewall IP is present."
  }
}

run "spoke_without_hub_firewall_no_route" {
  command = plan

  variables {
    hub_firewall_private_ip = null
  }

  # C24: relaxed precondition allows the plan with a null firewall IP
  assert {
    condition     = output.route_table_active == false
    error_message = "FR-228: spoke with no hub firewall IP must have route_table_active == false."
  }

  assert {
    condition     = output.subnet_route_table_attached["development"] == false && output.subnet_route_table_attached["function-app"] == false
    error_message = "FR-228: no spoke workload subnet may attach the RT when the hub firewall is absent."
  }

  # spoke firewall output is always null regardless
  assert {
    condition     = output.firewall_private_ip == null
    error_message = "spoke firewall_private_ip must be null."
  }

  # route table resource still present (C22)
  assert {
    condition     = output.route_table_name == "rt-net-shd-sp01-npd-swc-001"
    error_message = "C22: spoke route table resource must still be created."
  }
}
