# C-018 (Amendment 2026-05-31) — private endpoint negative paths (FR-027).
#  - missing_subnet:   enabled=true with no subnet → resource precondition fails.
#  - missing_zones:    enabled=true with empty zone list → precondition fails.
#  - malformed_subnet: non-subnet id → variable validation fails.

variables {
  canonical_name      = "aif-shd-shd-sp01-npd-uks-001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags = {
    managed_by      = "terraform"
    tenant          = "sp01"
    environment     = "npd"
    region          = "uksouth"
    repo            = "tcsatheesh/tfiac"
    usecase         = "shd"
    stack_purpose   = "svc"
    service_purpose = "shd"
  }
  engine_record = {
    service_type    = "aifoundry"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags = {
      managed_by      = "terraform"
      tenant          = "sp01"
      environment     = "npd"
      region          = "uksouth"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "shd"
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

run "missing_subnet" {
  command = plan

  variables {
    private_endpoint_enabled   = true
    private_endpoint_subnet_id = null
    private_dns_zone_ids       = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"]
  }

  expect_failures = [
    azurerm_private_endpoint.this,
  ]
}

run "missing_zones" {
  command = plan

  variables {
    private_endpoint_enabled   = true
    private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-spk-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-shd-spk-npd-swc-001/subnets/snet-dev-shd-spk-npd-swc-001"
    private_dns_zone_ids       = []
  }

  expect_failures = [
    azurerm_private_endpoint.this,
  ]
}

run "malformed_subnet" {
  command = plan

  variables {
    private_endpoint_enabled   = true
    private_endpoint_subnet_id = "not-a-valid-subnet-id"
    private_dns_zone_ids       = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"]
  }

  expect_failures = [
    var.private_endpoint_subnet_id,
  ]
}
