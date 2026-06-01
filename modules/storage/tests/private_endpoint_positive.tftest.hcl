# C-035 / FR-034 — private_endpoint_enabled = true ⇒ public access disabled and
# exactly one private endpoint with subresource "blob" registering into the
# supplied privatelink.blob.core.windows.net zone.

variables {
  canonical_name      = "stshdshdsp01npduks001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags                = {}
  engine_record = {
    service_type    = "storage"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags            = {}
    azure_max       = 24
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true

  private_endpoint_enabled   = true
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-net-shd-sp01-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-sp01-npd-swc-001/subnets/snet-dev"
  private_dns_zone_ids       = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"]
}

mock_provider "azurerm" {}

run "public_access_disabled" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.public_network_access_enabled == false
    error_message = "private_endpoint_enabled=true must set public_network_access_enabled = false."
  }
}

run "one_private_endpoint_subresource_blob" {
  command = plan

  assert {
    condition     = length(azurerm_private_endpoint.this) == 1
    error_message = "Exactly one private endpoint must be provisioned when enabled."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this[*].private_service_connection[0].subresource_names[0]) == "blob"
    error_message = "The storage private endpoint subresource must be \"blob\"."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this[*].private_dns_zone_group[0].private_dns_zone_ids[0]) == var.private_dns_zone_ids[0]
    error_message = "The private endpoint must register into the supplied privatelink.blob.core.windows.net zone."
  }
}
