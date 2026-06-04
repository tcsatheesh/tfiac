# Happy path — non-empty maps create one resource per entry.

mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  role_assignments = {
    account-kv-crypto-enc = {
      scope_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv1"
      role_definition_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b86a8fe4-44ce-4948-aee5-eccb2c155cd7"
      principal_id       = "11111111-1111-1111-1111-111111111111"
      principal_type     = "ServicePrincipal"
    }
    project-storage-blob = {
      scope_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st1"
      role_definition_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
      principal_id       = "22222222-2222-2222-2222-222222222222"
      principal_type     = "ServicePrincipal"
    }
  }
  cosmos_sql_role_assignments = {
    project-cosmos-data = {
      cosmos_account_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.DocumentDB/databaseAccounts/cdb1"
      sql_role_definition_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.DocumentDB/databaseAccounts/cdb1/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
      principal_id           = "22222222-2222-2222-2222-222222222222"
    }
  }
}

run "creates_all_assignments" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.this) == 2
    error_message = "Expected two control-plane role assignments."
  }

  assert {
    condition     = length(azapi_resource.cosmos_sql) == 1
    error_message = "Expected one Cosmos DB SQL role assignment."
  }

  assert {
    condition     = azurerm_role_assignment.this["account-kv-crypto-enc"].principal_type == "ServicePrincipal"
    error_message = "principal_type must pass through to the assignment."
  }
}
