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

run "baseline_hub_plan" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    region          = "swedencentral"
    repo            = "tcsatheesh/tfiac"
  }

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
    subscription_id = "00000000-0000-0000-0000-000000000000"
    region          = "swedencentral"
    repo            = "tcsatheesh/tfiac"
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
