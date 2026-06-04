# FR-043 / VC-21 (Amendment 2026-06-04) — Foundry project-level capability host
# day-one parity. With network_injection_enabled unset (default false) the
# project module emits ZERO capability hosts; the project body is byte-for-byte
# the pre-FR-043 state (only the project resource + the C-014 diag setting).

variables {
  canonical_name      = "aifp-shd-shd-sp01-dev-uks-001"
  resource_group_name = "rg-svc-shd-sp01-dev-uks-001"
  location            = "uksouth"
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags = {
      managed_by      = "terraform"
      tenant          = "sp01"
      environment     = "dev"
      region          = "uksouth"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "shd"
    }
    azure_max = 32
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  parent_account_id                 = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001"
  # network_injection_enabled omitted ⇒ default false
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

run "no_capability_host_by_default" {
  command = plan

  assert {
    condition     = length(azapi_resource.capability_host) == 0
    error_message = "FR-043 / VC-21: default (network_injection_enabled=false) must emit ZERO project capability hosts."
  }

  # The project resource itself is still emitted unchanged.
  assert {
    condition     = azapi_resource.this.name == var.canonical_name
    error_message = "FR-043 / VC-21: the bare project resource must still be emitted on the default path."
  }
}
