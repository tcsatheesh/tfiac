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

# Shared hub baseline inputs (CIDR plan from temp/hub.npd.vnet.yaml).
variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  region          = "swedencentral"
  repo            = "tcsatheesh/tfiac"
  role            = "hub"
  topology        = "hub"
  tenant          = "hub"
  environment     = "npd"
  address_space   = ["10.240.4.0/23"]
  subnets = {
    "development"    = "10.240.4.0/26"
    "pre-production" = "10.240.4.64/26"
    "api-management" = "10.240.4.144/28"
    "buildsvr"       = "10.240.4.160/28"
    "bastion"        = "10.240.4.192/28"
    "firewall"       = "10.240.5.0/26"
    "firewall-mgmt"  = "10.240.5.64/26"
  }
}

run "baseline_hub_plan" {
  command = plan

  assert {
    condition     = output.vnet_name == "vnet-hub-npd-sdc-001"
    error_message = "vnet_name must be vnet-hub-npd-sdc-001."
  }

  assert {
    condition     = output.resource_group_name == "rg-hub-npd-sdc-001"
    error_message = "resource_group_name must be rg-hub-npd-sdc-001."
  }

  assert {
    condition     = output.subnet_names["bastion"] == "AzureBastionSubnet"
    error_message = "bastion subnet must use the Azure literal name."
  }

  assert {
    condition     = output.subnet_names["development"] == "snet-development-hub-npd-sdc-001"
    error_message = "development subnet must use engine purpose-keyed naming."
  }

  assert {
    condition     = output.peered_spoke_vnet_names == []
    error_message = "default spoke_peerings must be empty when caller does not register any."
  }
}

run "registers_spoke_peering" {
  command = plan

  variables {
    spoke_peerings = {
      "sp01-npd" = {
        remote_vnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sp01-npd-sdc-001/providers/Microsoft.Network/virtualNetworks/vnet-sp01-npd-sdc-001"
        remote_vnet_name = "vnet-sp01-npd-sdc-001"
      }
    }
  }

  assert {
    condition     = contains(output.peered_spoke_vnet_names, "vnet-sp01-npd-sdc-001")
    error_message = "spoke_peerings entry must surface in peered_spoke_vnet_names output."
  }
}
