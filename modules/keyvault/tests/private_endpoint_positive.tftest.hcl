# VC-16 / C-050 / FR-041 — key vault private_endpoint_enabled = true ⇒ public
# network access disabled, network_acls default_action = Deny, and exactly one
# private endpoint with subresource "vault" registering into the supplied
# privatelink.vaultcore.azure.net zone.

variables {
  canonical_name      = "kvshdshdsp01npduks001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags                = {}
  engine_record = {
    service_type    = "keyvault"
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
  private_dns_zone_ids       = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"]
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000001"
      object_id       = "00000000-0000-0000-0000-000000000002"
      client_id       = "00000000-0000-0000-0000-000000000003"
    }
  }
}

run "public_access_disabled" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "private_endpoint_enabled=true must set public_network_access_enabled = false."
  }

  assert {
    condition     = one(azurerm_key_vault.this.network_acls).default_action == "Deny"
    error_message = "private_endpoint_enabled=true must set network_acls default_action = Deny."
  }
}

run "one_private_endpoint_subresource_vault" {
  command = plan

  assert {
    condition     = length(azurerm_private_endpoint.this) == 1
    error_message = "Exactly one private endpoint must be provisioned when enabled."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this[*].private_service_connection[0].subresource_names[0]) == "vault"
    error_message = "The key vault private endpoint subresource must be \"vault\"."
  }

  assert {
    condition     = one(azurerm_private_endpoint.this[*].private_dns_zone_group[0].private_dns_zone_ids[0]) == var.private_dns_zone_ids[0]
    error_message = "The private endpoint must register into the supplied privatelink.vaultcore.azure.net zone."
  }
}
