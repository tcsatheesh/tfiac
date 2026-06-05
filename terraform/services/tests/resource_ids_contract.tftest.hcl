# FR-061 (Amendment 2026-06-04) — the `resource_ids` / `resource_names`
# cross-stack contract MUST expose EVERY emitted service (except the svc RG),
# byte-identical to keys(module.naming.names) minus the RG entry
# (contracts/cross-stack-outputs.md). This regression guards the gap that
# silently omitted `module.cosmosdb` (and
# `module.container_app_environment`) from the map, so
# `local.resource_ids[cosmos_name]` failed with "Invalid
# index" in a downstream consumer.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "storage", purpose = "agt" },
    { type = "cosmosdb" },
    { type = "search" },
    { type = "keyvault" },
  ]
  overrides                    = {}
  private_by_default           = true
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
      vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001"
      subnets = {
        development = {
          id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001/subnets/snet-dev-uc1-sp01-npd-swc-001"
          name           = "snet-dev-uc1-sp01-npd-swc-001"
          address_prefix = "10.0.0.0/24"
        }
        agents = {
          id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001/subnets/snet-agt-uc1-sp01-npd-swc-001"
          name           = "snet-agt-uc1-sp01-npd-swc-001"
          address_prefix = "10.0.1.0/24"
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
        cogsvc       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"
        openai       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
        aiservices   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com"
        "cosmos-sql" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com"
        blob         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
        search       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"
        vault        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
      }
    }
  }
}

run "resource_ids_and_names_cover_every_service" {
  command = plan

  # The contract key set = keys(naming) minus the single resource_group entry.
  # resource_names is keys-only (known at plan), so assert exact set equality.
  assert {
    condition = setsubtract(
      keys(module.naming.names),
      [for k, e in module.naming.names : k if e.service_type == "resource_group"]
    ) == toset(keys(output.resource_names))
    error_message = "FR-061: resource_names must cover every emitted service except the svc RG (byte-identical to keys(naming) minus the RG)."
  }

  # The same key set must back resource_ids (its values are computed, but the
  # key set is known at plan).
  assert {
    condition     = toset(keys(output.resource_ids)) == toset(keys(output.resource_names))
    error_message = "FR-061: resource_ids and resource_names must share an identical key set."
  }

  # Explicit guards for the services that were previously omitted.
  assert {
    condition = alltrue([
      for k, e in module.naming.names : contains(keys(output.resource_names), k)
      if contains(["cosmosdb", "container_app_environment"], e.service_type)
    ])
    error_message = "FR-061: cosmosdb and container_app_environment canonical names must appear in the cross-stack contract."
  }
}
