# C-013 (Amendment 2026-05-31) — apim hub-only defence-in-depth.
# This wrapper MUST hard-fail at plan time when topology != "hub".
variables {
  canonical_name      = "apim-shd-shd-hub-npd-uks-001"
  resource_group_name = "rg-svc-shd-hub-npd-uks-001"
  location            = "uksouth"
  tags                = {}
  engine_record = {
    service_type    = "apim"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 50
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  topology                          = "spoke"
}

mock_provider "azurerm" {}

run "rejects_spoke_topology" {
  command         = plan
  expect_failures = [resource.terraform_data.topology_hub_only_guard]
}
