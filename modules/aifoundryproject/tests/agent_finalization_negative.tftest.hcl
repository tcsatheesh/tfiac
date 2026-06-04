# FR-060 (Amendment 2026-06-04) — agent-finalization phasing, negative path.
# With agent_finalization_enabled = false (but network_injection_enabled = true)
# the project module must DEFER its Agents capability host — it hard-depends on
# the project-MI data-plane grants issued by the separate 007-rbac stack. The
# project resource itself is still created.

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
  network_injection_enabled         = true

  # FR-060 — defer the capability host (first bootstrap pass, before rbac).
  agent_finalization_enabled = false
}

mock_provider "azurerm" {}
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001/projects/aifp-shd-shd-sp01-dev-uks-001"
    }
  }
}

run "finalization_off_defers_project_capability_host" {
  command = apply

  # Deferred: project capability host absent.
  assert {
    condition     = length(azapi_resource.capability_host) == 0
    error_message = "FR-060: agent_finalization_enabled=false must emit zero project capability host."
  }

  # Preserved: the project resource itself is still created.
  assert {
    condition     = azapi_resource.this.name == "aifp-shd-shd-sp01-dev-uks-001"
    error_message = "FR-060: deferring finalization must NOT drop the project resource."
  }
}
