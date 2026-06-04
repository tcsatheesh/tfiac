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

  # FR-062 (Amendment 2026-06-04) — the ACCOUNT-level Agents capability host is
  # platform-managed: the injected-Foundry RP auto-provisions
  # `<account>@aml_aiagentservice` (the RP enforces one host per account
  # ClientId, so an explicit Terraform `agents` host always Conflicts).
  # `azapi_resource.capability_host` is therefore removed from modules/aifoundry,
  # and asserting on it here would be a reference to an undeclared resource. The
  # BYO connections are bound on the project-level host instead
  # (modules/aifoundryproject, FR-043/VC-20).

  assert {
    condition     = local.config.public_network_access == "Disabled"
    error_message = "FR-031: an injected account must be private (publicNetworkAccess=Disabled)."
  }

  # FR-040 (Amendment 2026-06-02) — injected-account body aligned with
  # Microsoft's proven network-secured reference: preview API version (VC-9),
  # explicit networkAcls (VC-10) and disableLocalAuth=false (VC-11).
  assert {
    condition     = azapi_resource.this.type == "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
    error_message = "FR-040 / VC-9: the injected account must use the 2025-04-01-preview API version."
  }

  assert {
    condition     = azapi_resource.this.body.properties.networkAcls.defaultAction == "Deny" && azapi_resource.this.body.properties.networkAcls.bypass == "AzureServices"
    error_message = "FR-040 / VC-10: the injected account body must set networkAcls.defaultAction=Deny + bypass=AzureServices."
  }

  assert {
    condition     = azapi_resource.this.body.properties.disableLocalAuth == false
    error_message = "FR-040 / VC-11: the injected account body must set disableLocalAuth=false."
  }
}


# FR-031 (Amendment 2026-06-04) — the AzureStorageAccount connection target must
# be the Blob endpoint URI (not the resource ID); the RP rejects a resource ID
# with HTTP 400 ValidationError. Cosmos/Search targets stay as resource IDs.
run "storage_connection_target_is_blob_uri" {
  command = plan

  assert {
    condition     = azapi_resource.agent_storage_connection[0].body.properties.target == "https://stuc1sp01devswc001.blob.core.windows.net"
    error_message = "FR-031: AzureStorageAccount connection target must be the Blob endpoint URI derived from the storage account name."
  }

  assert {
    condition     = azapi_resource.agent_storage_connection[0].body.properties.metadata.ResourceId == var.agent_storage_account_id
    error_message = "FR-031: the connection metadata.ResourceId must remain the storage account resource ID."
  }

  assert {
    condition     = azapi_resource.agent_cosmos_connection[0].body.properties.target == var.agent_cosmosdb_account_id && azapi_resource.agent_search_connection[0].body.properties.target == var.agent_search_service_id
    error_message = "FR-031: Cosmos/Search connection targets must remain the resource IDs (only Storage needs a URI)."
  }
}
