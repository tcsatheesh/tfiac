# FR-060 (Amendment 2026-06-04) — agent-finalization phasing, negative path.
# With agent_finalization_enabled = false (but injection + App Insights ON) the
# wrapper must DEFER the three resources that depend on 007-rbac grants: the App
# Insights tracing connection and the account-level Agents capability host. The
# account, its networkInjections body and the three BYO connections must still
# be present (they do not depend on rbac grants).

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

  # FR-027 PE inputs (injection requires a private account).
  private_endpoint_enabled   = true
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-sp01-spk-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-sp01-spk-npd-swc-001/subnets/snet-dev-sp01-spk-npd-swc-001"
  private_dns_zone_ids = [
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com",
  ]

  # App Insights tracing ON (its connection is one of the deferred resources).
  application_insights_enabled = true

  # FR-031 injection inputs (ON — so the account body + BYO connections build).
  network_injection_enabled = true
  agent_subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-sp01-spk-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-sp01-spk-npd-swc-001/subnets/snet-agents-sp01-spk-npd-swc-001"
  agent_storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.Storage/storageAccounts/stuc1sp01devswc001"
  agent_cosmosdb_account_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.DocumentDB/databaseAccounts/cosuc1sp01devswc001"
  agent_search_service_id   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.Search/searchServices/srchuc1sp01devswc001"

  # FR-060 — defer the rbac-dependent resources (first bootstrap pass).
  agent_finalization_enabled = false
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

run "finalization_off_defers_rbac_dependent_resources" {
  command = plan

  # Deferred: App Insights connection absent.
  assert {
    condition     = length(azapi_resource.appinsights_connection) == 0
    error_message = "FR-060: agent_finalization_enabled=false must emit zero appinsights_connection."
  }

  # Deferred: account-level Agents capability host absent.
  assert {
    condition     = length(azapi_resource.capability_host) == 0
    error_message = "FR-060: agent_finalization_enabled=false must emit zero account capability_host."
  }

  # Preserved: the account still carries its injection body.
  assert {
    condition     = contains(keys(azapi_resource.this.body.properties), "networkInjections")
    error_message = "FR-060: deferring finalization must NOT drop the account networkInjections body."
  }

  # Preserved: the three BYO connections (they do not depend on rbac grants).
  assert {
    condition     = length(azapi_resource.agent_storage_connection) == 1 && length(azapi_resource.agent_cosmos_connection) == 1 && length(azapi_resource.agent_search_connection) == 1
    error_message = "FR-060: deferring finalization must NOT drop the three BYO connections."
  }
}
