# FR-031 (Amendment 2026-06-02) — Hosted-Agent injection negative paths.
#  - missing_byo_id:  injection on but one BYO id null → resource precondition fails.
#  - public_account:  injection on but private_endpoint_enabled=false → precondition fails.
#  - malformed_subnet: non-subnet agent_subnet_id → variable validation fails.

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

  private_endpoint_enabled   = true
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-sp01-spk-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-sp01-spk-npd-swc-001/subnets/snet-dev-sp01-spk-npd-swc-001"
  private_dns_zone_ids = [
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com",
  ]

  agent_subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-sp01-spk-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-sp01-spk-npd-swc-001/subnets/snet-agents-sp01-spk-npd-swc-001"
  agent_storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.Storage/storageAccounts/stuc1sp01devswc001"
  agent_cosmosdb_account_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.DocumentDB/databaseAccounts/cosuc1sp01devswc001"
  agent_search_service_id   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.Search/searchServices/srchuc1sp01devswc001"
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

run "missing_byo_id" {
  command = plan

  variables {
    network_injection_enabled = true
    agent_search_service_id   = null
  }

  expect_failures = [
    azapi_resource.this,
  ]
}

run "public_account" {
  command = plan

  variables {
    network_injection_enabled = true
    private_endpoint_enabled  = false
  }

  expect_failures = [
    azapi_resource.this,
  ]
}

run "malformed_subnet" {
  command = plan

  variables {
    network_injection_enabled = true
    agent_subnet_id           = "not-a-valid-subnet-id"
  }

  expect_failures = [
    var.agent_subnet_id,
  ]
}
