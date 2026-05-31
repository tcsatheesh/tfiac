# C-018 (Amendment 2026-05-31) — private endpoint positive path (FR-027).
# With private_endpoint_enabled = true the wrapper emits a single
# azurerm_private_endpoint (Cognitive Services group id "account") wired to the
# supplied subnet + DNS zones, and the account defaults to
# publicNetworkAccess = "Disabled".

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

  # C-018 PE inputs.
  private_endpoint_enabled   = true
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-spk-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-shd-spk-npd-swc-001/subnets/snet-dev-shd-spk-npd-swc-001"
  private_dns_zone_ids = [
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com",
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com",
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com",
  ]
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

run "private_endpoint_emitted" {
  command = plan

  assert {
    condition     = length(azurerm_private_endpoint.this) == 1
    error_message = "C-018: private_endpoint_enabled=true must emit exactly one azurerm_private_endpoint."
  }

  assert {
    condition     = azurerm_private_endpoint.this[0].name == "pep-aif-shd-shd-sp01-npd-uks-001"
    error_message = "C-018: PE name must be pep-<canonical_name>."
  }

  assert {
    condition     = azurerm_private_endpoint.this[0].subnet_id == var.private_endpoint_subnet_id
    error_message = "C-018: PE subnet_id must equal the supplied private_endpoint_subnet_id."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this[0].private_service_connection[0].subresource_names) == "account"
    error_message = "C-018: PE private_service_connection subresource group id must be \"account\"."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this[0].private_dns_zone_group[0].private_dns_zone_ids) == 3
    error_message = "C-018: PE private_dns_zone_group must reference all three (cogsvc/openai/aiservices) zone IDs."
  }

  assert {
    condition     = local.config.public_network_access == "Disabled"
    error_message = "C-018: with the PE enabled, the account publicNetworkAccess default must be \"Disabled\"."
  }
}
