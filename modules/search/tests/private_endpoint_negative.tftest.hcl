# C-039 / FR-035 — default (private_endpoint_enabled = false) ⇒ public network
# access stays enabled and zero private endpoints are provisioned (day-one
# parity).

variables {
  canonical_name      = "srch-shd-shd-sp01-npd-uks-001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags                = {}
  engine_record = {
    service_type    = "search"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 60
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
}

mock_provider "azurerm" {}

run "public_access_enabled_by_default" {
  command = plan

  assert {
    condition     = azurerm_search_service.this.public_network_access_enabled == true
    error_message = "Default (PE off) must leave public_network_access_enabled = true."
  }
}

run "no_private_endpoint_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_private_endpoint.this) == 0
    error_message = "No private endpoint must be provisioned when private_endpoint_enabled = false."
  }
}
