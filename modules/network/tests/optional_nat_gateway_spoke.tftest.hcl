# FR-230 — optional spoke NAT gateway egress (module level).
#
# A spoke owns its own NAT gateway (NAT is not transitive over peering). Same
# generalised engine path as the hub (FR-229) behind enable_spoke_nat_gateway.
#
# Run 1 (enable_spoke_nat_gateway = true, hub firewall GONE => firewall IP null):
#   post-teardown egress. The NAT gateway associates with every spoke subnet
#   whose role has needs_nat_egress = true — the needs_route_table workload
#   subnets PLUS the delegated managed-environment role container-apps (FR-231).
#   route_table_active is false (no firewall route), so the spoke now egresses
#   SOLELY via its NAT gateway.
# Run 2 (enable_spoke_nat_gateway = true, hub firewall PRESENT => firewall IP set):
#   coexistence. route_table_active is true AND the NAT gateway is associated
#   (dormant behind the firewall UDR which wins on routing precedence).
# Run 3 (default, enable_spoke_nat_gateway unset => false): nothing created;
#   nat_gateway_id is null and every subnet_nat_attached entry is false.
#
# Plan-only, fully mocked, -backend=false. (nat_gateway_id is a computed
# resource id, unknown at plan; the enabled path is proven via the deterministic
# subnet_nat_attached boolean map, mirroring the FR-229 fix.)

variables {
  input = {
    tenant        = "sp01"
    environment   = "npd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "net"
    repo          = "tcsatheesh/tfiac"
  }
  role          = "spoke"
  address_space = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "logic-app"      = "10.240.2.128/28"
    "function-app"   = "10.240.2.144/28"
    "preprod-logic"  = "10.240.2.160/28"
    "preprod-func"   = "10.240.2.176/28"
    "container-apps" = "10.240.2.192/27"
  }
  hub_vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "spoke_nat_gateway_enabled_post_teardown" {
  command = plan

  variables {
    enable_spoke_nat_gateway = true
    hub_firewall_private_ip  = null
  }

  # associated with every egress (needs_route_table) spoke workload subnet
  assert {
    condition = (
      output.subnet_nat_attached["development"] == true
      && output.subnet_nat_attached["pre-production"] == true
      && output.subnet_nat_attached["function-app"] == true
      && output.subnet_nat_attached["logic-app"] == true
      && output.subnet_nat_attached["preprod-func"] == true
      && output.subnet_nat_attached["preprod-logic"] == true
    )
    error_message = "FR-230/C34: the spoke NAT gateway must associate with all needs_route_table workload subnets."
  }

  # FR-231: the delegated managed-environment role (container-apps) carries NO
  # shared firewall route (needs_route_table = false) yet still attaches the NAT
  # gateway because it needs an egress path to initialise its managed env.
  assert {
    condition     = output.subnet_nat_attached["container-apps"] == true
    error_message = "FR-231: the spoke NAT gateway MUST associate with container-apps (needs_nat_egress = true) even though needs_route_table = false."
  }

  # post-teardown: no firewall route, so the spoke egresses solely via NAT
  assert {
    condition     = output.route_table_active == false
    error_message = "FR-230: with the hub firewall gone (firewall IP null), route_table_active must be false."
  }
}

run "spoke_nat_gateway_coexists_with_firewall" {
  command = plan

  variables {
    enable_spoke_nat_gateway = true
    hub_firewall_private_ip  = "10.240.5.4"
  }

  # coexistence: firewall route still present AND NAT associated (dormant)
  assert {
    condition = (
      output.route_table_active == true
      && output.subnet_nat_attached["development"] == true
    )
    error_message = "FR-230/C36: NAT association and the firewall UDR must coexist (route_table_active true AND NAT attached)."
  }
}

run "spoke_nat_gateway_disabled_by_default" {
  command = plan

  variables {
    hub_firewall_private_ip = null
  }

  # default (enable_spoke_nat_gateway unset => false): nothing created
  assert {
    condition     = output.nat_gateway_id == null
    error_message = "FR-230/C33: nat_gateway_id must be null by default (enable_spoke_nat_gateway = false)."
  }
  assert {
    condition = (
      output.subnet_nat_attached["development"] == false
      && output.subnet_nat_attached["pre-production"] == false
      && output.subnet_nat_attached["function-app"] == false
      && output.subnet_nat_attached["container-apps"] == false
    )
    error_message = "FR-230/C33: no subnet may associate the NAT gateway when the toggle is false."
  }
}
