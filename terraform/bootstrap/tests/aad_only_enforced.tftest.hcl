# T016 - The state SA MUST be AAD-only + PE-only + TLS1.2 + HTTPS + LRS.
variables {
  subscription_id    = "00000000-0000-0000-0000-000000000000"
  region             = "swc"
  tenant             = "hub"
  environment        = "npd"
  repo               = "tcsatheesh/tfiac"
  operator_object_id = "11111111-1111-1111-1111-111111111111"
  gh_oidc_object_id  = "22222222-2222-2222-2222-222222222222"
  remote_state_override = {
    pe_subnet_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001/subnets/snet-dev-shd-hub-npd-swc-001"
    pe_subnet_vnetid = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net-shd-hub-npd-swc-001/providers/Microsoft.Network/virtualNetworks/vnet-net-shd-hub-npd-swc-001"
    blob_zone_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-shd-hub-prd-swc-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    blob_zone_name   = "privatelink.blob.core.windows.net"
    dns_zone_rg      = "rg-dns-shd-hub-prd-swc-001"
  }
  build_vm_override = {
    principal_id = "33333333-3333-3333-3333-333333333333"
  }
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "azapi" {}
mock_provider "random" {}

run "aad_only_and_pe_only_enforced" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.shared_access_key_enabled == false
    error_message = "FR-002: shared_access_key_enabled MUST be false (AAD-only)."
  }

  assert {
    condition     = azurerm_storage_account.this.default_to_oauth_authentication == true
    error_message = "FR-002: default_to_oauth_authentication MUST be true."
  }

  assert {
    condition     = azurerm_storage_account.this.public_network_access_enabled == false
    error_message = "FR-002: public_network_access_enabled MUST be false (PE-only)."
  }

  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled == true
    error_message = "FR-002: https_traffic_only_enabled MUST be true."
  }

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "FR-002: min_tls_version MUST be TLS1_2."
  }

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false
    error_message = "FR-002: allow_nested_items_to_be_public MUST be false."
  }

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "LRS"
    error_message = "FR-002: account_replication_type MUST be LRS."
  }

  assert {
    condition     = azurerm_storage_account.this.account_kind == "StorageV2"
    error_message = "FR-002: account_kind MUST be StorageV2."
  }

  assert {
    condition     = azurerm_storage_account.this.account_tier == "Standard"
    error_message = "FR-002: account_tier MUST be Standard."
  }
}
