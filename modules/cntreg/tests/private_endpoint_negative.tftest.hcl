# C-020 / FR-029 — default (private_endpoint_enabled = false) preserves the
# prior behaviour: engine-default Standard SKU, public access enabled, zero
# private endpoints.

variables {
  canonical_name      = "crshdshdsp01npduks001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags                = {}
  engine_record = {
    service_type    = "container_registry"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 50
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
}

mock_provider "azurerm" {}

run "default_standard_sku" {
  command = plan

  assert {
    condition     = azurerm_container_registry.this.sku == "Standard"
    error_message = "Default (no PE) must keep the engine-default Standard SKU."
  }
}

run "default_public_access_enabled" {
  command = plan

  assert {
    condition     = azurerm_container_registry.this.public_network_access_enabled == true
    error_message = "Default (no PE) must keep public_network_access_enabled = true."
  }
}

run "default_zero_private_endpoints" {
  command = plan

  assert {
    condition     = length(azurerm_private_endpoint.this) == 0
    error_message = "Default (no PE) must provision zero private endpoints."
  }
}
