# FR-031 (Amendment 2026-06-02) — Hosted-Agent injection default-off parity.
# With network_injection_enabled unset (false) the module emits NO connections,
# NO capability host, and the account body has NO networkInjections attribute —
# byte-for-byte parity with the post-FR-028 state (A-031-04).

variables {
  canonical_name      = "aif-uc1-uc1-sp01-dev-swc-001"
  resource_group_name = "rg-svc-uc1-sp01-dev-swc-001"
  location            = "swedencentral"
  tags = {
    managed_by      = "terraform"
    tenant          = "sp01"
    environment     = "dev"
    region          = "swedencentral"
    repo            = "tcsatheesh/tfiac"
    usecase         = "uc1"
    stack_purpose   = "svc"
    service_purpose = "uc1"
  }
  engine_record = {
    service_type    = "aifoundry"
    service_purpose = "uc1"
    stack_purpose   = null
    parent          = null
    tags = {
      managed_by      = "terraform"
      tenant          = "sp01"
      environment     = "dev"
      region          = "swedencentral"
      repo            = "tcsatheesh/tfiac"
      usecase         = "uc1"
      stack_purpose   = "svc"
      service_purpose = "uc1"
    }
    azure_max = 260
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_subscription.current
    values = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000001"
    }
  }
}
mock_provider "azapi" {}

run "default_off_no_injection" {
  command = plan

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "networkInjections")
    error_message = "FR-031 / A-031-04: with injection disabled the account body must NOT contain networkInjections."
  }

  assert {
    condition     = length(azapi_resource.agent_storage_connection) == 0 && length(azapi_resource.agent_cosmos_connection) == 0 && length(azapi_resource.agent_search_connection) == 0
    error_message = "FR-031: with injection disabled no BYO connections must be emitted."
  }

  assert {
    condition     = length(azapi_resource.capability_host) == 0
    error_message = "FR-031: with injection disabled no capabilityHosts child must be emitted."
  }
}
