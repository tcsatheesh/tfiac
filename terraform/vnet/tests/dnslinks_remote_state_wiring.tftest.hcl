# T099 - FR-211 / FR-215 / plan §7 — root stack wires mocked
# data.terraform_remote_state.dns into module.dnslinks in both hub
# and spoke roles, planning exactly 2 link resources each.

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azurerm" { alias = "hub" }
mock_provider "azurerm" { alias = "dns" }
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

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

run "dnslinks_wires_dns_remote_state_hub" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    repo            = "tcsatheesh/tfiac"
    region          = "swc"
    tenant          = "hub"
    environment     = "npd"
    role            = "hub"
    usecase         = "shd"
    address_space   = ["10.240.4.0/23"]
    subnets = {
      "development"    = "10.240.4.0/26"
      "pre-production" = "10.240.4.64/26"
      "api-management" = "10.240.4.144/28"
      "buildsvr"       = "10.240.4.160/28"
      "bastion"        = "10.240.4.192/26"
      "firewall"       = "10.240.5.0/26"
      "firewall-mgmt"  = "10.240.5.64/26"
    }
    dns_state_backend = {
      subscription_id      = "00000000-0000-0000-0000-000000000000"
      resource_group_name  = "stcwe-rg-tfs-01"
      storage_account_name = "stcwetfstate01"
      container_name       = "tfstate"
      key                  = "hub/prd/dns.tfstate"
    }
  }

  assert {
    condition     = output.dnslinks_count == 2
    error_message = "FR-211 / FR-215: hub role must plan exactly 2 vnet-links for the mocked 2-zone DNS remote state."
  }
}

run "dnslinks_wires_dns_remote_state_spoke" {
  command = plan

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
      subscription_id      = "00000000-0000-0000-0000-000000000002"
      resource_group_name  = "stcwe-rg-tfs-01"
      storage_account_name = "stcwetfstate01"
      container_name       = "tfstate"
      key                  = "hub/prd/dns.tfstate"
    }
  }

  # Override azurerm_client_config.current for the spoke subscription
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000002"
    }
  }

  assert {
    condition     = output.dnslinks_count == 2
    error_message = "FR-211 / FR-215: spoke role must plan exactly 2 vnet-links for the mocked 2-zone DNS remote state."
  }
}
