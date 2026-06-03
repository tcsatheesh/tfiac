# FR-230 — root stack forwards enable_spoke_nat_gateway end-to-end. With the
# toggle off (default), the stack's nat_gateway_id output is null (count = 0,
# deterministic at plan time). The enabled path's resource id is only known
# after apply, so it is exercised by the engine module test instead; here the
# enabled run just proves the wiring plans cleanly.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000002"
  repo            = "tcsatheesh/tfiac"
  region          = "swc"
  tenant          = "sp01"
  environment     = "npd"
  role            = "spoke"
  usecase         = "shd"
  address_space   = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "logic-app"      = "10.240.2.128/28"
    "function-app"   = "10.240.2.144/28"
    "preprod-logic"  = "10.240.2.160/28"
    "preprod-func"   = "10.240.2.176/28"
    "container-apps" = "10.240.2.192/27"
  }
  hub_state_backend = {
    resource_group_name  = "rg-tfstate-hub-npd-swc-001"
    storage_account_name = "satfstatehubnpdswc001"
    container_name       = "tfstate"
    key                  = "hub/npd/vnet.tfstate"
    subscription_id      = "00000000-0000-0000-0000-000000000001"
  }
  # Post-teardown hub state: firewall gone => firewall_private_ip omitted (null).
  hub_state_override = {
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
    vnet_name           = "vnet-net-shd-hub-npd-swc-001"
    resource_group_name = "rg-net-shd-hub-npd-swc-001"
  }
  dns_state_backend = {
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    resource_group_name  = "stcwe-rg-tfs-01"
    storage_account_name = "stcwetfstate01"
    container_name       = "tfstate"
    key                  = "hub/prd/dns.tfstate"
  }
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}
mock_provider "azurerm" { alias = "hub" }
mock_provider "azurerm" { alias = "dns" }

override_data {
  target = data.terraform_remote_state.dns
  values = {
    outputs = {
      zone_ids = {
        "blob" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
      }
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "spoke_nat_gateway_disabled_by_default_root_plans" {
  command = plan

  assert {
    condition     = output.nat_gateway_id == null
    error_message = "FR-230/C33: root stack nat_gateway_id must be null by default."
  }
}

run "spoke_nat_gateway_enabled_root_plans" {
  command = plan

  variables {
    enable_spoke_nat_gateway = true
  }

  # The enabled NAT gateway id is computed (unknown at plan); we only prove the
  # root stack wires the toggle and plans cleanly. The deterministic egress
  # assertions live in the engine module test.
  assert {
    condition     = output.vnet_name == "vnet-net-shd-sp01-npd-swc-001"
    error_message = "FR-230: spoke stack with enable_spoke_nat_gateway=true must plan and emit the spoke vnet name."
  }
}
