# VC-12 / FR-041 — private-by-default master ON (default).
# With private_by_default = true (the new default) and NO explicit per-service
# enable_* flags, every selected Private-Link-capable service resolves its
# private-endpoint requirement to TRUE via coalesce(null, true), the vnet/dns
# remote-state stubs resolve subnet + zone ids, and the Foundry-tracing App
# Insights is enabled.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "aifoundry" },
    { type = "storage" },
    { type = "search" },
    { type = "keyvault" },
    { type = "container_registry" },
  ]
  overrides = {}
  # private_by_default defaults to true — left unset on purpose.
  private_endpoint_subnet_role = "development"
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
        cogsvc     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"
        openai     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
        aiservices = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com"
        blob       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
        search     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"
        acr        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
        vault      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
      }
    }
  }
}

run "private_by_default_resolves_all_pe" {
  command = plan

  assert {
    condition     = local.aifoundry_pe_required
    error_message = "VC-12: aifoundry_pe_required must resolve true from the master (coalesce(null, true))."
  }
  assert {
    condition     = local.storage_pe_required
    error_message = "VC-12: storage_pe_required must resolve true from the master."
  }
  assert {
    condition     = local.search_pe_required
    error_message = "VC-12: search_pe_required must resolve true from the master."
  }
  assert {
    condition     = local.keyvault_pe_required
    error_message = "VC-12: keyvault_pe_required must resolve true from the master."
  }
  assert {
    condition     = local.acr_pe_required
    error_message = "VC-12: acr_pe_required must resolve true from the master."
  }
  assert {
    condition     = local.appinsights_enabled
    error_message = "VC-12: Foundry App Insights must resolve enabled from the master."
  }
  assert {
    condition     = length(local.keyvault_pe_zone_ids) == 1 && local.keyvault_pe_subnet_id != null
    error_message = "VC-12: key vault PE subnet + vault zone must resolve from the remote state."
  }
}
