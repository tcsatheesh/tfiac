# T017 - The PE MUST land in the hub vnet subnet returned by the
# upstream vnet remote state under var.pe_subnet_role (default "development").
variables {
  subscription_id    = "00000000-0000-0000-0000-000000000000"
  region             = "swc"
  tenant             = "hub"
  environment        = "npd"
  repo               = "tcsatheesh/tfiac"
  operator_object_id = "11111111-1111-1111-1111-111111111111"
  gh_oidc_object_id  = null
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

run "pe_subnet_matches_override" {
  command = plan

  assert {
    condition     = azurerm_private_endpoint.sa.subnet_id == var.remote_state_override.pe_subnet_id
    error_message = "FR-005 / C-001: PE subnet_id MUST come from the dev subnet emitted by the upstream vnet stack."
  }

  assert {
    condition     = azurerm_private_endpoint.sa.private_service_connection[0].subresource_names[0] == "blob"
    error_message = "FR-005: PE subresource MUST be \"blob\"."
  }

  assert {
    condition     = azurerm_private_endpoint.sa.private_service_connection[0].is_manual_connection == false
    error_message = "FR-005: PE MUST be auto-approved (is_manual_connection = false)."
  }

  assert {
    condition     = azurerm_private_dns_a_record.sa.zone_name == var.remote_state_override.blob_zone_name
    error_message = "FR-005: A-record MUST be in the privatelink.blob zone returned by the dns remote state."
  }

  assert {
    condition     = azurerm_private_dns_a_record.sa.name == "sttfsshdhubnpdswc001"
    error_message = "FR-005: A-record name MUST equal the SA canonical name."
  }
}

run "rbac_skipped_when_object_ids_null" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.gh_oidc_contributor) == 0
    error_message = "Constitution II: GH OIDC role assignment MUST be skipped when gh_oidc_object_id is null."
  }
}
