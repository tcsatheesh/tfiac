# VC-15 / FR-041 — master ON with a PE-capable service but missing remote-state
# backends hard-fails at plan time. private_by_default = true selects a storage
# service (PE-capable) but supplies neither vnet_state_backend nor
# dns_state_backend, so the variable-level requirement AND the
# check.private_by_default_requires_backends guard fire.

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
  ]
  overrides          = {}
  private_by_default = true
  # vnet_state_backend / dns_state_backend intentionally omitted.
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

# Bypass the remote-state reads (the backends are intentionally null) so the
# variable-level requirement is what surfaces as the catchable failure rather
# than a raw backend "empty containerName" load error.
override_data {
  target = data.terraform_remote_state.vnet[0]
  values = {
    outputs = {
      subnets = {}
    }
  }
}

override_data {
  target = data.terraform_remote_state.dns[0]
  values = {
    outputs = {
      zone_ids = {}
    }
  }
}

run "master_on_missing_backend_fails" {
  command = plan
  expect_failures = [
    var.dns_state_backend,
  ]
}
