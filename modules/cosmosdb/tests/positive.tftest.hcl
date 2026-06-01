# FR-032 (Amendment 2026-06-02) — Cosmos DB wrapper positive path. Asserts the
# account is private-by-default (public_network_access_enabled = false), AAD-only
# (local_authentication_disabled = true), diag wired to the shared hub LA, and an
# always-on private endpoint targeting subresource "Sql" + the cosmos-sql zone.

variables {
  canonical_name      = "cosmos-shd-shd-sp01-dev-swc-001"
  resource_group_name = "rg-svc-shd-sp01-dev-swc-001"
  location            = "swedencentral"
  tags = {
    managed_by    = "terraform"
    tenant        = "sp01"
    environment   = "dev"
    region        = "swedencentral"
    repo          = "tcsatheesh/tfiac"
    usecase       = "shd"
    stack_purpose = "svc"
  }
  engine_record = {
    service_type    = "cosmosdb"
    service_purpose = "shd"
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

run "private_by_default" {
  command = plan

  assert {
    condition     = azurerm_cosmosdb_account.this.public_network_access_enabled == false
    error_message = "FR-032: Cosmos DB account must have public_network_access_enabled = false (private-by-default mandate)."
  }

  assert {
    condition     = azurerm_cosmosdb_account.this.local_authentication_disabled == true
    error_message = "FR-032: Cosmos DB account must disable key-based local auth (AAD-only)."
  }

  assert {
    condition     = azurerm_cosmosdb_account.this.kind == "GlobalDocumentDB"
    error_message = "FR-032: Cosmos DB account must be the SQL/NoSQL (GlobalDocumentDB) API."
  }
}

run "private_endpoint_always_on" {
  command = plan

  assert {
    condition     = azurerm_private_endpoint.this.subnet_id == var.private_endpoint_subnet_id
    error_message = "FR-032: the private endpoint NIC must land in private_endpoint_subnet_id."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this.private_service_connection).subresource_names == tolist(["Sql"])
    error_message = "FR-032: the private endpoint must target the Sql subresource group id."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this.private_dns_zone_group).private_dns_zone_ids == var.private_dns_zone_ids
    error_message = "FR-032: the private endpoint must register into the supplied cosmos-sql zone(s)."
  }
}

run "diag_wired_to_shared_la" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.to_hub_la) == 1
    error_message = "C-014: diagnostic_settings_enabled defaults to true but no diag resource was emitted."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.to_hub_la[0].log_analytics_workspace_id == var.shared_log_analytics_workspace_id
    error_message = "C-014: diag log_analytics_workspace_id diverged from the input."
  }
}
