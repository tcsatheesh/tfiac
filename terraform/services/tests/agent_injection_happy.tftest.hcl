# FR-033 — Hosted-Agent network-injection passthrough happy path. With the
# toggle on, the BYO trio (storage+cosmosdb+search) + aifoundry selected, a
# private Foundry account, and vnet/dns remote-state stubs, the stack resolves
# the agent subnet (by the 'agents' role) and wires injection into the
# aifoundry module (one instance each of the four legs).

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
    { type = "cosmosdb" },
    { type = "search" },
  ]
  overrides = {}
  # Pin the pre-FR-041 master OFF so this legacy scenario keeps its day-one
  # (public, no auto-PE) shape; private-by-default is exercised by the
  # dedicated private_by_default_*/aifoundry_private_deps_* tests.
  private_by_default                 = false
  enable_aifoundry_private_endpoint  = true
  enable_aifoundry_network_injection = true
  # FR-033 / FR-042: the BYO Storage + Search backing the Agents capability host
  # must be private when the Foundry account is private. (Cosmos DB is always
  # private per FR-032.)
  enable_storage_private_endpoint = true
  enable_search_private_endpoint  = true
  private_endpoint_subnet_role    = "development"
  agent_subnet_role               = "agents"
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
      }
    }
  }
}

run "agent_injection_wired" {
  command = plan

  assert {
    condition     = local.agent_subnet_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001/subnets/snet-agt-uc1-sp01-npd-swc-001"
    error_message = "FR-033: agent_subnet_id must resolve from the vnet remote state for the 'agents' role."
  }

  assert {
    condition     = length([for k, v in module.aifoundry : v if v != null]) == 1
    error_message = "FR-033: exactly one aifoundry module instance must be created."
  }

  assert {
    condition     = length([for k, v in module.cosmosdb : v if v != null]) == 1
    error_message = "FR-033: exactly one cosmosdb (BYO) module instance must be created."
  }
}
