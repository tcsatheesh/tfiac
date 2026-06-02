# C-052 / FR-041 parity — key vault private_endpoint_enabled = false (default):
# public network access stays enabled, network_acls default_action = Allow, and
# NO private endpoint is provisioned. Reproduces the pre-FR-041 behaviour.

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
  # private_endpoint_enabled defaults to false — left unset on purpose.
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

run "public_access_preserved_no_pe" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == true
    error_message = "Default (PE off) must preserve public_network_access_enabled = true."
  }

  assert {
    condition     = one(azurerm_key_vault.this.network_acls).default_action == "Allow"
    error_message = "Default (PE off) must keep network_acls default_action = Allow."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 0
    error_message = "Default (PE off) must provision no private endpoint."
  }
}
