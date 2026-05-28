###############################################################################
# terraform/bootstrap/main.tf
#
# Provisions the per-environment Terraform state storage account + the
# `tfstate` container. Run this stack ONCE per subscription (or whenever a new
# environment is added).
#
# Outputs the values that every other stack needs to pass via
# `terraform init -backend-config=...`.
###############################################################################

module "naming" {
  source = "../../modules/naming"
  input  = local.input
}

locals {
  rg_name      = [for k, v in module.naming.names : k if v.service_type == "resource_group"][0]
  storage_name = [for k, v in module.naming.names : k if v.service_type == "storage"][0]
  tags         = [for k, v in module.naming.names : v.tags if v.service_type == "resource_group"][0]
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.region
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
