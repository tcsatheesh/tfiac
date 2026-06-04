# FR-044 / C-060 (userOwnedStorage) + FR-045 / C-061 (Key Vault connection),
# Amendment 2026-06-04 — template-exact-match. When account_storage_account_id
# is supplied the wrapper attaches it as properties.userOwnedStorage AND an
# 'accountstorage' AzureStorageAccount connection (target = Blob URI). When
# keyvault_account_id is supplied the wrapper attaches a 'keyvault'
# AzureKeyVault connection (authType AccountManagedIdentity). Both are inert
# (zero-count, no body property) when their inputs are null.

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

  # FR-044 / FR-045 inputs.
  account_storage_account_id         = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.Storage/storageAccounts/stactsp01devswc001"
  account_storage_connection_enabled = true
  keyvault_account_id                = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-uc1-sp01-dev-swc-001/providers/Microsoft.KeyVault/vaults/kvuc1sp01devswc001"
  keyvault_connection_enabled        = true
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

run "user_owned_storage_emitted" {
  command = plan

  assert {
    condition     = contains(keys(azapi_resource.this.body.properties), "userOwnedStorage")
    error_message = "FR-044: with account_storage_account_id set the account body must include userOwnedStorage."
  }

  assert {
    condition     = azapi_resource.this.body.properties.userOwnedStorage[0].resourceId == var.account_storage_account_id
    error_message = "FR-044: userOwnedStorage[0].resourceId must equal account_storage_account_id."
  }

  assert {
    condition     = length(azapi_resource.account_storage_connection) == 1
    error_message = "FR-044: account_storage_account_id must emit exactly one 'accountstorage' connection."
  }

  assert {
    condition     = azapi_resource.account_storage_connection[0].name == "accountstorage"
    error_message = "FR-044 / C-025: the userOwnedStorage connection must use the fixed name 'accountstorage'."
  }

  assert {
    condition     = azapi_resource.account_storage_connection[0].body.properties.category == "AzureStorageAccount"
    error_message = "FR-044: the userOwnedStorage connection category must be AzureStorageAccount."
  }

  assert {
    condition     = azapi_resource.account_storage_connection[0].body.properties.target == "https://stactsp01devswc001.blob.core.windows.net"
    error_message = "FR-044: the userOwnedStorage connection target must be the Blob endpoint URI derived from the storage account name."
  }

  assert {
    condition     = azapi_resource.account_storage_connection[0].body.properties.metadata.ResourceId == var.account_storage_account_id
    error_message = "FR-044: the userOwnedStorage connection metadata.ResourceId must equal account_storage_account_id."
  }
}

run "keyvault_connection_emitted" {
  command = plan

  assert {
    condition     = length(azapi_resource.keyvault_connection) == 1
    error_message = "FR-045: keyvault_account_id must emit exactly one 'keyvault' connection."
  }

  assert {
    condition     = azapi_resource.keyvault_connection[0].name == "keyvault"
    error_message = "FR-045 / C-025: the Key Vault connection must use the fixed name 'keyvault'."
  }

  assert {
    condition     = azapi_resource.keyvault_connection[0].body.properties.category == "AzureKeyVault"
    error_message = "FR-045: the Key Vault connection category must be AzureKeyVault."
  }

  assert {
    condition     = azapi_resource.keyvault_connection[0].body.properties.authType == "AccountManagedIdentity"
    error_message = "FR-045: the Key Vault connection authType must be AccountManagedIdentity (template-exact)."
  }

  assert {
    condition     = azapi_resource.keyvault_connection[0].body.properties.target == var.keyvault_account_id
    error_message = "FR-045: the Key Vault connection target must equal keyvault_account_id."
  }

  assert {
    condition     = azapi_resource.keyvault_connection[0].body.properties.isSharedToAll == true
    error_message = "FR-045: the Key Vault connection must be isSharedToAll = true so child projects inherit it."
  }

  assert {
    condition     = azapi_resource.keyvault_connection[0].body.properties.metadata.ResourceId == var.keyvault_account_id
    error_message = "FR-045: the Key Vault connection metadata.ResourceId must equal keyvault_account_id."
  }
}
