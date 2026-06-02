# C-014 (Amendment 2026-05-31) — every diagnostic-capable wrapper in the
# services stack wires `azurerm_monitor_diagnostic_setting` at the SHARED
# hub Log Analytics workspace surfaced via local.shared_la_workspace_id.
#
# Mocking strategy (per spec.md C-014, recorded in tasks T091): the test
# `override_data`s the `terraform_remote_state.hub_log` lookup with a stub
# workspace id, then asserts that:
#   (a) the root output `shared_la_workspace_id` equals the stub, and
#   (b) every selected wrapper (covering every code path that wires the
#       shared LA — keyvault / storage / app_insights / container_registry /
#       search / openai / aifoundry / language / doc_intel / function_app /
#       logic_app / aml_workspace / apim) instantiates exactly once.
#
# Per-wrapper proof that the diag resource ITSELF picks up
# `var.shared_log_analytics_workspace_id` lives in each wrapper's
# `tests/positive.tftest.hcl` (e.g. modules/apim/tests/positive.tftest.hcl
# `run "diag_wired_to_shared_la"`). This root-stack test demonstrates the
# upstream half of the wiring: the value reaching every wrapper is the one
# read from terraform/log/'s remote state.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  topology        = "hub"
  tenant          = "hub"
  environment     = "dev"
  region          = "uks"
  usecase         = "shd"
  repo            = "tcsatheesh/tfiac"
  services = [
    { type = "keyvault" },
    { type = "storage" },
    { type = "app_insights" },
    { type = "container_registry" },
    { type = "search" },
    { type = "openai" },
    { type = "aifoundry" },
    { type = "language" },
    { type = "doc_intel" },
    { type = "function_app" },
    { type = "logic_app" },
    { type = "aml_workspace" },
    { type = "apim" },
  ]
  overrides = {}
  # Pre-FR-041 parity: this legacy all-types diag test keeps the master OFF.
  private_by_default = false
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

run "every_diag_capable_wrapper_sees_shared_la" {
  command = plan

  assert {
    condition     = output.shared_la_workspace_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
    error_message = "diag_wired_to_hub_la: shared_la_workspace_id output did not resolve to the mocked terraform_remote_state value (C-014 wiring broken)."
  }

  assert {
    condition     = length(keys(module.keyvault)) == 1
    error_message = "diag_wired_to_hub_la: keyvault wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.storage)) == 1
    error_message = "diag_wired_to_hub_la: storage wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.app_insights)) == 1
    error_message = "diag_wired_to_hub_la: app_insights wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.container_registry)) == 1
    error_message = "diag_wired_to_hub_la: container_registry wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.search)) == 1
    error_message = "diag_wired_to_hub_la: search wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.openai)) == 1
    error_message = "diag_wired_to_hub_la: openai wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.aifoundry)) == 1
    error_message = "diag_wired_to_hub_la: aifoundry wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.language)) == 1
    error_message = "diag_wired_to_hub_la: language wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.doc_intel)) == 1
    error_message = "diag_wired_to_hub_la: doc_intel wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.function_app)) == 1
    error_message = "diag_wired_to_hub_la: function_app wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.logic_app)) == 1
    error_message = "diag_wired_to_hub_la: logic_app wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.aml_workspace)) == 1
    error_message = "diag_wired_to_hub_la: aml_workspace wrapper not instantiated."
  }

  assert {
    condition     = length(keys(module.apim)) == 1
    error_message = "diag_wired_to_hub_la: apim wrapper not instantiated."
  }
}
