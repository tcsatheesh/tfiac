# FR-052 — Azure SQL + Data Factory happy path. Selecting sql_server and
# data_factory (both private-only) requires the vnet/dns remote-state backends;
# the stack resolves the PE subnet (development role) + the sql / datafactory /
# adf zone ids and wires them into module.sql_server + module.data_factory.
# With storage + keyvault also selected, the ADF cross-service linked-service
# refs are populated.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp03"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "storage" },
    { type = "keyvault" },
    { type = "sql_server" },
    { type = "data_factory" },
  ]
  overrides                        = {}
  private_endpoint_subnet_role     = "development"
  enable_storage_private_endpoint  = true
  enable_keyvault_private_endpoint = true
  vnet_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp03/npd/vnet.tfstate"
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
      vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp03-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp03-npd-swc-001"
      subnets = {
        development = {
          id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp03-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp03-npd-swc-001/subnets/snet-dev-uc1-sp03-npd-swc-001"
          name           = "snet-dev-uc1-sp03-npd-swc-001"
          address_prefix = "10.240.8.0/26"
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
        "blob"        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
        "vault"       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
        "sql"         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net"
        "datafactory" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.datafactory.azure.net"
        "adf"         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.adf.azure.net"
      }
    }
  }
}

run "sql_and_datafactory_wired" {
  command = plan

  assert {
    condition     = local.sql_pe_subnet_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp03-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp03-npd-swc-001/subnets/snet-dev-uc1-sp03-npd-swc-001"
    error_message = "FR-052: sql_pe_subnet_id must resolve from the vnet remote state for the development role."
  }

  assert {
    condition     = length(local.sql_pe_zone_ids) == 1
    error_message = "FR-052: sql_pe_zone_ids must resolve the single sql (privatelink.database.windows.net) zone id."
  }

  assert {
    condition     = length(local.datafactory_pe_zone_ids) == 1 && length(local.datafactory_portal_zone_ids) == 1
    error_message = "FR-052: data factory must resolve one datafactory (dataFactory) zone + one adf (portal) zone."
  }

  assert {
    condition     = length([for k, v in module.sql_server : k]) == 1
    error_message = "FR-052: exactly one sql_server module instance must be created."
  }

  assert {
    condition     = length([for k, v in module.data_factory : k]) == 1
    error_message = "FR-052: exactly one data_factory module instance must be created."
  }
}
