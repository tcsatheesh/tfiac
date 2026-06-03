# FR-229 — optional hub NAT gateway egress (module level).
#
# Run 1 (enable_hub_nat_gateway = true): the NAT gateway is created, its
# resource id is non-null, and it is associated with exactly the workload
# subnets that have needs_route_table = true (development, pre-production,
# buildsvr) and NOT with non-egress roles (api-management). Coexistence: the
# firewall and route-table outputs are UNCHANGED vs default (route_table_active
# true, development subnet still attaches the shared route table).
# Run 2 (default, enable_hub_nat_gateway unset => false): nothing is created;
# nat_gateway_id is null and every subnet_nat_attached entry is false.
#
# Plan-only, fully mocked, -backend=false.

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

run "nat_gateway_enabled" {
  command = plan

  variables {
    enable_hub_nat_gateway = true
  }

  # associated with the egress (needs_route_table) workload subnets
  assert {
    condition = (
      output.subnet_nat_attached["development"] == true
      && output.subnet_nat_attached["pre-production"] == true
      && output.subnet_nat_attached["buildsvr"] == true
    )
    error_message = "FR-229/C27: the NAT gateway must associate with development, pre-production, and buildsvr."
  }

  # NOT associated with non-egress roles
  assert {
    condition     = output.subnet_nat_attached["api-management"] == false
    error_message = "FR-229/C27: the NAT gateway must NOT associate with api-management (needs_route_table = false)."
  }

  # coexistence: firewall + route table unchanged (firewall still on by default)
  assert {
    condition     = output.route_table_active == true
    error_message = "FR-229/C30: enabling the NAT gateway must not disturb route_table_active (firewall still on)."
  }

  assert {
    condition     = output.subnet_route_table_attached["development"] == true
    error_message = "FR-229/C30: enabling the NAT gateway must not change the shared route-table attachment."
  }
}

run "nat_gateway_disabled_by_default" {
  command = plan

  # default (enable_hub_nat_gateway unset => false): nothing created
  assert {
    condition     = output.nat_gateway_id == null
    error_message = "FR-229/C26: nat_gateway_id must be null by default (enable_hub_nat_gateway = false)."
  }
  assert {
    condition = (
      output.subnet_nat_attached["development"] == false
      && output.subnet_nat_attached["pre-production"] == false
      && output.subnet_nat_attached["buildsvr"] == false
      && output.subnet_nat_attached["api-management"] == false
    )
    error_message = "FR-229/C26: no subnet may associate the NAT gateway when the toggle is false."
  }
}
