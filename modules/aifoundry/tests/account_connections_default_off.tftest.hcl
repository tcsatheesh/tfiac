# FR-044 / C-060 + FR-045 / C-061 (Amendment 2026-06-04) — default-off path.
# With account_storage_account_id and keyvault_account_id at their null
# defaults, the account body must NOT include userOwnedStorage and neither the
# 'accountstorage' nor the 'keyvault' connection may be emitted (zero-count),
# so day-one behaviour is byte-for-byte preserved.

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

run "no_account_connections_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "userOwnedStorage")
    error_message = "FR-044: by default the account body must NOT include userOwnedStorage."
  }

  assert {
    condition     = length(azapi_resource.account_storage_connection) == 0
    error_message = "FR-044: by default no 'accountstorage' connection may be emitted."
  }

  assert {
    condition     = length(azapi_resource.keyvault_connection) == 0
    error_message = "FR-045: by default no 'keyvault' connection may be emitted."
  }
}
