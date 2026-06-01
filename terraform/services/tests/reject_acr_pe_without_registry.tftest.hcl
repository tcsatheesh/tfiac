# C-020 / FR-029 — enabling the ACR private endpoint without a
# `container_registry` selection hard-fails at plan time via
# check.acr_pe_requires_registry.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "openai" },
  ]
  overrides                                  = {}
  enable_container_registry_private_endpoint = true
  private_endpoint_subnet_role               = "development"
  vnet_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/npd/vnet.tfstate"
  }
  dns_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "hub/prd/dns.tfstate"
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000099"
      client_id       = "00000000-0000-0000-0000-000000000098"
      object_id       = "00000000-0000-0000-0000-000000000097"
    }
  }
  mock_data "azurerm_subscription" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000"
      subscription_id       = "00000000-0000-0000-0000-000000000000"
      tenant_id             = "00000000-0000-0000-0000-000000000099"
      display_name          = "mock-subscription"
      location_placement_id = "Public_2014-09-01"
      quota_id              = "PayAsYouGo_2014-09-01"
      spending_limit        = "Off"
      state                 = "Enabled"
      tags                  = {}
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

override_data {
  target = data.terraform_remote_state.hub_log
  values = {
    outputs = {
      workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
    }
  }
}

override_data {
  target = data.terraform_remote_state.vnet[0]
  values = {
    outputs = {
      vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001"
      subnets = {
        development = {
          id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001/subnets/snet-dev-uc1-sp01-npd-swc-001"
          name           = "snet-dev-uc1-sp01-npd-swc-001"
          address_prefix = "10.0.0.0/24"
        }
      }
    }
  }
}

override_data {
  target = data.terraform_remote_state.dns[0]
  values = {
    outputs = {
      zone_ids = {
        acr = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
      }
    }
  }
}

run "rejects_acr_pe_without_registry" {
  command = plan
  expect_failures = [
    check.acr_pe_requires_registry,
  ]
}
