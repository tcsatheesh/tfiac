# T046 - root-stack stable plan for spoke topology. terraform_remote_state.hub
# is mocked via override_data.

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
  }
  hub_state_backend = {
    resource_group_name  = "rg-tfstate-hub-npd-swc-001"
    storage_account_name = "satfstatehubnpdswc001"
    container_name       = "tfstate"
    key                  = "hub/npd/vnet.tfstate"
    subscription_id      = "00000000-0000-0000-0000-000000000001"
  }
  hub_state_override = {
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
    vnet_name           = "vnet-net-shd-hub-npd-swc-001"
    resource_group_name = "rg-net-shd-hub-npd-swc-001"
    firewall_private_ip = "10.240.5.4"
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
        "blob"      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
        "vaultcore" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
      }
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "plan_zero_diff_spoke_first" {
  command = plan

  assert {
    condition     = output.vnet_name == "vnet-net-shd-sp01-npd-swc-001"
    error_message = "Spoke first-plan vnet_name diverges from snapshot."
  }
}

run "plan_zero_diff_spoke_second" {
  command = plan

  assert {
    condition     = output.vnet_name == "vnet-net-shd-sp01-npd-swc-001"
    error_message = "Spoke second-plan vnet_name diverged."
  }
}
