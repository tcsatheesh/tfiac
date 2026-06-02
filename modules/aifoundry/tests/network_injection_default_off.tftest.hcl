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

  # FR-040 (Amendment 2026-06-02) — day-one parity: with injection OFF the
  # account keeps the GA API version and the body omits networkAcls +
  # disableLocalAuth (those keys live only in the injection branch). VC-9/10/11.
  assert {
    condition     = azapi_resource.this.type == "Microsoft.CognitiveServices/accounts@2025-09-01"
    error_message = "FR-040 / VC-9: with injection disabled the account must keep the 2025-09-01 GA API version."
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "networkAcls")
    error_message = "FR-040 / VC-10: with injection disabled the account body must NOT contain networkAcls."
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "disableLocalAuth")
    error_message = "FR-040 / VC-11: with injection disabled the account body must NOT contain disableLocalAuth."
  }
}
