# FR-043 / VC-20 + VC-22 (Amendment 2026-06-04) — Foundry project-level
# capability host positive coverage. With network_injection_enabled = true the
# project module emits ONE Microsoft.CognitiveServices/accounts/projects/
# capabilityHosts named "agents", kind=Agents, referencing the three fixed BYO
# connection names (agentstorage/agentcosmos/agentsearch) and carrying NO
# customerSubnet (C-057 — the subnet binding lives on the account-level host).

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
}

mock_provider "azurerm" {}
mock_provider "azapi" {
  # Give azapi resources a parseable ARM id so the azurerm diagnostic-setting
  # target_resource_id validates under `command = apply` (the project body is
  # only known after apply because schema_validation_enabled = false on the
  # capability host).
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001/projects/aifp-shd-shd-sp01-dev-uks-001"
    }
  }
}

run "project_capability_host_emitted" {
  command = apply

  assert {
    condition     = length(azapi_resource.capability_host) == 1
    error_message = "FR-043 / VC-20: network_injection_enabled=true must emit exactly one project capability host."
  }

  assert {
    condition     = azapi_resource.capability_host[0].name == "agents"
    error_message = "FR-043 / VC-20: project capability host must be named \"agents\"."
  }

  assert {
    condition     = azapi_resource.capability_host[0].parent_id == azapi_resource.this.id
    error_message = "FR-043 / VC-20: project capability host parent_id must be the project resource id."
  }

  assert {
    condition     = azapi_resource.capability_host[0].body.properties.capabilityHostKind == "Agents"
    error_message = "FR-043 / VC-20: capabilityHostKind must be \"Agents\"."
  }
}

run "project_capability_host_connection_parity" {
  command = apply

  # VC-22 — the project host references the SAME fixed connection names the
  # account module creates (modules/aifoundry/locals.tf agent_conn_*).
  assert {
    condition     = one(azapi_resource.capability_host[0].body.properties.storageConnections) == "agentstorage" && one(azapi_resource.capability_host[0].body.properties.threadStorageConnections) == "agentcosmos" && one(azapi_resource.capability_host[0].body.properties.vectorStoreConnections) == "agentsearch"
    error_message = "FR-043 / VC-22: project host connection names must equal the account module fixed constants (agentstorage/agentcosmos/agentsearch)."
  }
}

run "project_capability_host_has_no_customer_subnet" {
  command = apply

  # C-057 — the agent customerSubnet lives ONLY on the account-level host; the
  # project host must NOT declare it.
  assert {
    condition     = !contains(keys(azapi_resource.capability_host[0].body.properties), "customerSubnet")
    error_message = "FR-043 / C-057: project capability host must NOT declare customerSubnet (it is inherited from the account-level host)."
  }

  # C-058 — aiServicesConnections is omitted (project is parented directly by
  # the account; no BYO-separate-foundry connection).
  assert {
    condition     = !contains(keys(azapi_resource.capability_host[0].body.properties), "aiServicesConnections")
    error_message = "FR-043 / C-058: project capability host must NOT declare aiServicesConnections in the direct-parent topology."
  }
}
