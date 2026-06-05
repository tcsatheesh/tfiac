# VC-14 / FR-041 — master OFF reproduces pre-amendment behaviour byte-for-byte.
# private_by_default = false and no explicit per-service enable_* flags. Every
# PE-capable service resolves coalesce(null, false) => false and no remote-state
# is required — exactly the pre-FR-041 day-one parity shape.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "storage" },
    { type = "search" },
    { type = "keyvault" },
    { type = "container_registry" },
  ]
  overrides          = {}
  private_by_default = false
  # No vnet/dns remote-state stubs: with the master off and no explicit PE
  # flags, no remote state is required (parity with pre-FR-041).
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

run "master_off_parity" {
  command = plan

  assert {
    condition     = local.storage_pe_required == false
    error_message = "VC-14: storage_pe_required must be false under master off."
  }
  assert {
    condition     = local.search_pe_required == false
    error_message = "VC-14: search_pe_required must be false under master off."
  }
  assert {
    condition     = local.keyvault_pe_required == false
    error_message = "VC-14: keyvault_pe_required must be false under master off."
  }
  assert {
    condition     = local.acr_pe_required == false
    error_message = "VC-14: acr_pe_required must be false under master off."
  }
  assert {
    condition     = local.vnet_state_required == false && local.dns_state_required == false
    error_message = "VC-14: no remote state may be required under master off with no explicit PE flags."
  }
}
