# Feature 000-bootstrap - root-stack composition.
# Resources (FR-001):
#   - 1 Resource Group
#   - 1 Storage Account (AAD-only, PE-only - FR-002, FR-003)
#   - 1 Blob Container "tfstate"
#   - 1 Private Endpoint into hub vnet (FR-005)
#   - 1 Private DNS A-record in privatelink.blob.core.windows.net (FR-005)
#   - up to 3 RBAC role assignments (FR-007)

module "naming" {
  source = "../../modules/naming"

  input    = local.naming_input
  services = local.engine_services
  children = local.engine_children
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_canonical_name
  location = local.region_full
  tags     = module.naming.names[local.rg_canonical_name].tags
}

# State SA - FR-002.
#   - public_network_access_enabled = false (PE-only)
#   - shared_access_key_enabled     = false (AAD-only)
#   - default_to_oauth_authentication = true
#   - min_tls_version                 = TLS1_2
#   - https_traffic_only_enabled      = true
#   - allow_nested_items_to_be_public = false
#   - replication LRS, kind StorageV2, tier Standard
#   - versioning + 14-day soft delete (blob + container)
resource "azurerm_storage_account" "this" {
  name                = local.sa_canonical_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = module.naming.names[local.sa_canonical_name].tags

  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"

  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  public_network_access_enabled    = false
  cross_tenant_replication_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }

    container_delete_retention_policy {
      days = 14
    }
  }
}

# Blob container - FR-003.
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Private Endpoint into hub vnet dev subnet - FR-005, C-001.
resource "azurerm_private_endpoint" "sa" {
  name                = local.pe_canonical_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = local.pe_subnet_id
  tags                = module.naming.names[local.pe_canonical_name].tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

# A-record in privatelink.blob.core.windows.net - FR-005.
# Name = SA name; value = PE NIC private IP.
resource "azurerm_private_dns_a_record" "sa" {
  name                = local.sa_canonical_name
  zone_name           = local.blob_zone_name
  resource_group_name = local.dns_zone_rg
  ttl                 = 300
  records             = [azurerm_private_endpoint.sa.private_service_connection[0].private_ip_address]
  tags                = module.naming.names[local.sa_canonical_name].tags
}

# ---- RBAC (FR-007) ----

# Operator (Storage Blob Data Owner) - optional.
resource "azurerm_role_assignment" "operator_owner" {
  count                = var.operator_object_id == null ? 0 : 1
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.operator_object_id
  description          = "Feature 000-bootstrap: human operator full data plane on tf state SA."
}

# Build VM MI (Storage Blob Data Contributor) - GH Actions self-hosted runner.
resource "azurerm_role_assignment" "build_vm_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.build_vm_principal_id
  description          = "Feature 000-bootstrap: hub build VM MI (self-hosted runner) data plane on tf state SA."
}

# GH OIDC SP (Storage Blob Data Contributor) - optional until SP exists.
resource "azurerm_role_assignment" "gh_oidc_contributor" {
  count                = var.gh_oidc_object_id == null ? 0 : 1
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.gh_oidc_object_id
  description          = "Feature 000-bootstrap: GitHub OIDC SP data plane on tf state SA (hub-npd env)."
}
