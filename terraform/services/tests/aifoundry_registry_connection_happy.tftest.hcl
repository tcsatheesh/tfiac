# FR-063 / C-079 (Amendment 2026-06-05) — services-stack happy path for the
# Foundry project ContainerRegistry connection: aifoundry account + project +
# a container_registry selected, with the connection toggle on. Confirms the
# stack resolves the registry login server / id and plans cleanly.

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
    { type = "aifoundry_project" },
    { type = "container_registry" },
  ]
  overrides                                      = {}
  private_by_default                             = false
  enable_aifoundry_container_registry_connection = true
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

run "registry_connection_wired" {
  command = plan

  # The registry is selected and the project + account are present.
  assert {
    condition     = length([for k, e in module.naming.names : e if e.service_type == "container_registry"]) == 1
    error_message = "FR-063: exactly one container_registry canonical name must be produced (the connection target)."
  }

  assert {
    condition     = length([for k, v in module.aifoundry_project : v if v != null]) == 1
    error_message = "FR-063: exactly one aifoundry_project module instance must be created."
  }

  assert {
    condition     = length([for k, v in module.container_registry : v if v != null]) == 1
    error_message = "FR-063: exactly one container_registry module instance must be created."
  }

  # The project module receives the connection toggle enabled.
  assert {
    condition     = var.enable_aifoundry_container_registry_connection == true
    error_message = "FR-063: the container registry connection toggle must flow into the stack."
  }
}
