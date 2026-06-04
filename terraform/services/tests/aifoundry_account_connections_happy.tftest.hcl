# FR-044 / C-060 (userOwnedStorage) + FR-045 / C-061 (Key Vault connection),
# Amendment 2026-06-04 — services-stack happy path matching the portal
# Standard-Agent template: a private Foundry account with Hosted-Agent network
# injection, TWO storage accounts (the BYO agent store + the account's own
# userOwnedStorage, disambiguated by purpose), one cosmosdb, one search and one
# (private) key vault wired as an AzureKeyVault connection.

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
    { type = "storage", purpose = "agt" },
    { type = "storage", purpose = "act" },
    { type = "cosmosdb" },
    { type = "search" },
    { type = "keyvault" },
  ]
  overrides = {}
  # Private-by-default makes the account + all PE-capable backings private and
  # auto-resolves every private endpoint from the supplied backends.
  private_by_default                 = true
  enable_aifoundry_private_endpoint  = true
  enable_aifoundry_network_injection = true
  # FR-044 / FR-045 toggles under test.
  enable_aifoundry_user_owned_storage  = true
  enable_aifoundry_keyvault_connection = true
  agent_storage_purpose                = "agt"
  account_storage_purpose              = "act"
  private_endpoint_subnet_role         = "development"
  agent_subnet_role                    = "agents"
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

run "account_connections_wired" {
  command = plan

  # Two storages selected; the agent (BYO) and account (userOwned) legs resolve
  # to DISTINCT storages by their service_purpose. The ids themselves are
  # computed (unknown at plan), so assert on the engine's known service_purpose
  # set instead: two storages with two distinct purposes.
  assert {
    condition     = length([for k, e in module.naming.names : e if e.service_type == "storage"]) == 2
    error_message = "FR-044: exactly two storage canonical names must be produced (BYO agent + account userOwned)."
  }

  assert {
    condition     = length(distinct([for k, e in module.naming.names : e.service_purpose if e.service_type == "storage"])) == 2
    error_message = "FR-044: the two storages must carry distinct service_purpose values so the agent/account legs are distinguishable."
  }

  # The aifoundry module receives both legs plus the keyvault connection target.
  assert {
    condition     = length([for k, v in module.aifoundry : v if v != null]) == 1
    error_message = "FR-044: exactly one aifoundry module instance must be created."
  }

  assert {
    condition     = length([for k, v in module.keyvault : v if v != null]) == 1
    error_message = "FR-045: exactly one keyvault module instance must be created (the connection target)."
  }
}
