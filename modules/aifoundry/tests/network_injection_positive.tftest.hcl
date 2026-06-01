# FR-031 (Amendment 2026-06-02) — Hosted-Agent network injection positive path.
# With network_injection_enabled = true (+ PE on + all four agent inputs) the
# wrapper adds properties.networkInjections (scenario=agent), three BYO account
# connections (Storage/Cosmos/Search) and one Agents capabilityHosts child.

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

  # FR-031 injection inputs.
  network_injection_enabled = true
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

run "network_injection_emitted" {
  command = plan

  assert {
    condition     = contains(keys(azapi_resource.this.body.properties), "networkInjections")
    error_message = "FR-031: with injection enabled the account body must include networkInjections."
  }

  assert {
    condition     = azapi_resource.this.body.properties.networkInjections[0].scenario == "agent"
    error_message = "FR-031 / VC-2: networkInjections[0].scenario must be \"agent\"."
  }

  assert {
    condition     = azapi_resource.this.body.properties.networkInjections[0].subnetArmId == var.agent_subnet_id
    error_message = "FR-031 / VC-2: networkInjections[0].subnetArmId must equal agent_subnet_id."
  }

  assert {
    condition     = azapi_resource.this.body.properties.networkInjections[0].useMicrosoftManagedNetwork == false
    error_message = "FR-031 / VC-2: useMicrosoftManagedNetwork must be false."
  }

  assert {
    condition     = length(azapi_resource.agent_storage_connection) == 1 && length(azapi_resource.agent_cosmos_connection) == 1 && length(azapi_resource.agent_search_connection) == 1
    error_message = "FR-031 / VC-4: injection must emit exactly one Storage, Cosmos and Search connection."
  }

  assert {
    condition     = length(azapi_resource.capability_host) == 1
    error_message = "FR-031 / VC-3: injection must emit exactly one Agents capabilityHosts child."
  }

  assert {
    condition     = azapi_resource.capability_host[0].body.properties.capabilityHostKind == "Agents"
    error_message = "FR-031 / VC-3: capabilityHostKind must be \"Agents\"."
  }

  assert {
    condition     = azapi_resource.capability_host[0].body.properties.customerSubnet == var.agent_subnet_id
    error_message = "FR-031 / VC-3: capability host customerSubnet must equal agent_subnet_id."
  }

  assert {
    condition     = one(azapi_resource.capability_host[0].body.properties.storageConnections) == "agentstorage" && one(azapi_resource.capability_host[0].body.properties.threadStorageConnections) == "agentcosmos" && one(azapi_resource.capability_host[0].body.properties.vectorStoreConnections) == "agentsearch"
    error_message = "FR-031 / VC-3 / C-025: capability host must reference agentstorage/agentcosmos/agentsearch connection names."
  }

  assert {
    condition     = local.config.public_network_access == "Disabled"
    error_message = "FR-031: an injected account must be private (publicNetworkAccess=Disabled)."
  }
}
