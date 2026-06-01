# C-021 / FR-030 — Container Apps internal environment happy path.
# enable_container_apps = true with a `container_app_environment` selection plus
# a vnet remote-state stub resolves the delegated subnet id + spoke vnet id and
# wires them into module.container_app_environment, which emits exactly one
# internal Managed Environment.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "spoke"
  tenant          = "sp01"
  environment     = "dev"
  region          = "swc"
  usecase         = "uc1"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "container_app_environment" },
  ]
  overrides                  = {}
  enable_container_apps      = true
  container_apps_subnet_role = "container-apps"
  vnet_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/npd/vnet.tfstate"
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
        "container-apps" = {
          id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001/subnets/snet-cae-uc1-sp01-npd-swc-001"
          name           = "snet-cae-uc1-sp01-npd-swc-001"
          address_prefix = "10.240.2.192/27"
        }
      }
    }
  }
}

run "container_apps_wired" {
  command = plan

  assert {
    condition     = local.container_apps_subnet_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001/subnets/snet-cae-uc1-sp01-npd-swc-001"
    error_message = "C-021: container_apps_subnet_id must resolve from the vnet remote state for the container-apps role."
  }

  assert {
    condition     = local.spoke_vnet_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-uc1-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-uc1-sp01-npd-swc-001"
    error_message = "C-021: spoke_vnet_id must resolve from the vnet remote state."
  }

  assert {
    condition     = length([for k, v in module.container_app_environment : v if v != null]) == 1
    error_message = "C-021: exactly one container_app_environment module instance must be created."
  }
}
