# FR-032 (Amendment 2026-06-02) — Cosmos DB wrapper negative paths. Asserts the
# input validators reject an empty/over-long/malformed name, a malformed PE
# subnet id, and an empty private_dns_zone_ids list (Cosmos is private-only).

variables {
  canonical_name      = "cosmos-shd-shd-sp01-dev-swc-001"
  resource_group_name = "rg-svc-shd-sp01-dev-swc-001"
  location            = "swedencentral"
  tags                = {}
  engine_record = {
    service_type    = "cosmosdb"
    service_purpose = null
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 44
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  private_endpoint_subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-sp01-npd-swc-001/subnets/snet-dev-net-shd-sp01-npd-swc-001"
  private_dns_zone_ids              = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-npd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com"]
}

mock_provider "azurerm" {}

run "empty_name_rejected" {
  command = plan
  variables { canonical_name = "" }
  expect_failures = [var.canonical_name]
}

run "uppercase_name_rejected" {
  command = plan
  variables { canonical_name = "Cosmos-BAD" }
  expect_failures = [var.canonical_name]
}

run "malformed_pe_subnet_rejected" {
  command = plan
  variables { private_endpoint_subnet_id = "not-a-subnet-id" }
  expect_failures = [var.private_endpoint_subnet_id]
}

run "empty_zone_ids_rejected" {
  command = plan
  variables { private_dns_zone_ids = [] }
  expect_failures = [var.private_dns_zone_ids]
}
