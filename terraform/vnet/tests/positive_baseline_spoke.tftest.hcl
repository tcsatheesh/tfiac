mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

# Shared sp01-npd spoke inputs.
variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  region          = "swedencentral"
  repo            = "tcsatheesh/tfiac"
  role            = "spoke"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "npd"
  address_space   = ["10.240.2.0/24"]
  subnets = {
    "development"    = "10.240.2.0/26"
    "pre-production" = "10.240.2.64/26"
    "logic-app"      = "10.240.2.128/28"
    "function-app"   = "10.240.2.144/28"
    "preprod-logic"  = "10.240.2.160/28"
    "preprod-func"   = "10.240.2.176/28"
  }
  # Hub state overrides (skip terraform_remote_state during tests).
  hub_vnet_id_override                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-npd-sdc-001/providers/Microsoft.Network/virtualNetworks/vnet-hub-npd-sdc-001"
  hub_firewall_private_ip_override     = "10.240.5.4"
  hub_peered_spoke_vnet_names_override = ["vnet-sp01-npd-sdc-001"]
}

run "baseline_spoke_plan" {
  command = plan

  assert {
    condition     = output.vnet_name == "vnet-sp01-npd-sdc-001"
    error_message = "vnet_name must be vnet-sp01-npd-sdc-001."
  }

  assert {
    condition     = output.resource_group_name == "rg-sp01-npd-sdc-001"
    error_message = "resource_group_name must be rg-sp01-npd-sdc-001."
  }

  assert {
    condition     = output.subnet_names["function-app"] == "snet-function-app-sp01-npd-sdc-001"
    error_message = "function-app subnet must use engine purpose-keyed naming."
  }

  assert {
    condition     = output.peering_enabled == true
    error_message = "peering must be enabled when hub_vnet_id_override is supplied."
  }
}
