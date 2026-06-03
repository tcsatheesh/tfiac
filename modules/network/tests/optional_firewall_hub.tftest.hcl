# FR-227 / FR-228 — optional hub Azure Firewall (module level).
#
# Run 1 (default, enable_hub_firewall unset => true): parity. The firewall
# outputs are non-null, route_table_active is true, and a workload subnet
# attaches the shared route table.
# Run 2 (enable_hub_firewall = false): the firewall is NOT created, all
# firewall-derived outputs are null, route_table_active is false, NO workload
# subnet attaches the shared route table, and the route table resource itself
# is still present (stable canonical name, C22).
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

run "firewall_enabled_by_default_parity" {
  command = plan

  # route table carries a real default route worth attaching
  assert {
    condition     = output.route_table_active == true
    error_message = "FR-228: default hub (firewall on) must have route_table_active == true."
  }

  # a workload subnet (needs_route_table = true) attaches the shared RT
  assert {
    condition     = output.subnet_route_table_attached["development"] == true
    error_message = "FR-228: with the firewall enabled, the development subnet must attach the shared route table."
  }

  # route table resource present with the engine canonical name
  assert {
    condition     = output.route_table_name == "rt-net-shd-hub-npd-swc-001"
    error_message = "C22: route table must be the engine canonical name."
  }
}

run "firewall_disabled_teardown" {
  command = plan

  variables {
    enable_hub_firewall = false
  }

  # firewall-derived outputs all collapse to null
  assert {
    condition     = output.firewall_private_ip == null
    error_message = "FR-227: firewall_private_ip must be null when the firewall is disabled."
  }

  assert {
    condition     = output.firewall_id == null
    error_message = "FR-227: firewall_id must be null when the firewall is disabled."
  }

  assert {
    condition     = output.firewall_pip_ip_tags == null
    error_message = "FR-227: firewall_pip_ip_tags must be null when the firewall is disabled."
  }

  # no real default route exists
  assert {
    condition     = output.route_table_active == false
    error_message = "FR-228: with the firewall disabled, route_table_active must be false."
  }

  # NO workload subnet attaches the shared route table
  assert {
    condition     = output.subnet_route_table_attached["development"] == false && output.subnet_route_table_attached["buildsvr"] == false
    error_message = "FR-228: no workload subnet may attach the shared route table when the firewall is disabled."
  }

  # the route table resource is still created (C22)
  assert {
    condition     = output.route_table_name == "rt-net-shd-hub-npd-swc-001"
    error_message = "C22: the route table resource must still be created (stable canonical name) when the firewall is disabled."
  }
}
