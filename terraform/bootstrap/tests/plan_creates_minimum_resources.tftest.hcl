# T015 - Bootstrap stack must plan exactly the minimum resource set
# (1 RG + 1 SA + 1 container + 1 PE + 1 A-record + 3 RBAC).
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

run "names_are_engine_emitted" {
  command = plan

  assert {
    condition     = output.storage_account_name == "sttfsshdhubnpdswc001"
    error_message = "SA name MUST be sttfsshdhubnpdswc001 (FR-004)."
  }

  assert {
    condition     = output.resource_group_name == "rg-tfs-shd-hub-npd-swc-001"
    error_message = "RG name MUST be rg-tfs-shd-hub-npd-swc-001 (FR-004)."
  }

  assert {
    condition     = output.container_name == "tfstate"
    error_message = "Container name MUST be exactly \"tfstate\" (FR-003)."
  }

  assert {
    condition     = output.private_dns_a_record_fqdn == "sttfsshdhubnpdswc001.privatelink.blob.core.windows.net"
    error_message = "A-record FQDN MUST be SA name + blob zone (FR-005)."
  }
}

run "rbac_three_assignments_when_all_principals_supplied" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.operator_owner) == 1
    error_message = "Operator role assignment MUST be created when operator_object_id is set (FR-007)."
  }

  assert {
    condition     = length(azurerm_role_assignment.gh_oidc_contributor) == 1
    error_message = "GH OIDC role assignment MUST be created when gh_oidc_object_id is set (FR-007)."
  }

  assert {
    condition     = azurerm_role_assignment.operator_owner[0].role_definition_name == "Storage Blob Data Owner"
    error_message = "Operator MUST get Storage Blob Data Owner (FR-007)."
  }

  assert {
    condition     = azurerm_role_assignment.build_vm_contributor.role_definition_name == "Storage Blob Data Contributor"
    error_message = "Build VM MI MUST get Storage Blob Data Contributor (FR-007)."
  }

  assert {
    condition     = azurerm_role_assignment.gh_oidc_contributor[0].role_definition_name == "Storage Blob Data Contributor"
    error_message = "GH OIDC SP MUST get Storage Blob Data Contributor (FR-007)."
  }

  assert {
    condition     = azurerm_role_assignment.build_vm_contributor.principal_id == "33333333-3333-3333-3333-333333333333"
    error_message = "Build VM MI principal_id MUST come from the data lookup / override (FR-007)."
  }
}
