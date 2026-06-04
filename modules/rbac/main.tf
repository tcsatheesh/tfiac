# Control-plane role assignments. azurerm auto-generates a stable name and
# tracks idempotency in state (C-064 — functionally equivalent to the portal's
# guid(scope, role, name) naming; the scope+role+principal triple is unique).
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope              = each.value.scope_id
  role_definition_id = each.value.role_definition_id
  principal_id       = each.value.principal_id
  principal_type     = each.value.principal_type
}

# Cosmos DB data-plane SQL role assignment (FR-057). Created via azapi because
# azurerm's cosmosdb_sql_role_assignment requires account/db names rather than a
# resource id, and we resolve everything by id from the services remote state.
# The resource name MUST be a GUID; derive it deterministically from the triple
# so re-runs are idempotent (uuidv5 over the account+role+principal).
resource "azapi_resource" "cosmos_sql" {
  for_each = var.cosmos_sql_role_assignments

  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15"
  parent_id = each.value.cosmos_account_id
  name = uuidv5(
    "url",
    "${each.value.cosmos_account_id}|${each.value.sql_role_definition_id}|${each.value.principal_id}",
  )

  body = {
    properties = {
      roleDefinitionId = each.value.sql_role_definition_id
      principalId      = each.value.principal_id
      scope            = each.value.cosmos_account_id
    }
  }

  response_export_values = ["id"]
}
