# modules/rbac

Generic role-assignment fan-out engine for the **007-rbac** stack. It is a thin,
reusable module that grants pre-resolved Azure RBAC role assignments and Cosmos
DB SQL (data-plane) role assignments. It does **not** resolve any target by
name, read remote state, or know anything about Azure AI Foundry — the consuming
stack (`terraform/rbac`) builds two fully-resolved maps and hands them in.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `role_assignments` | `map(object({ scope_id, role_definition_id, principal_id, principal_type }))` | `{}` | Control-plane `azurerm_role_assignment` fan-out, keyed by a stable caller id. |
| `cosmos_sql_role_assignments` | `map(object({ cosmos_account_id, sql_role_definition_id, principal_id }))` | `{}` | Cosmos DB data-plane `sqlRoleAssignments` fan-out (azapi). |

Empty maps produce zero resources (default-safe).

## Outputs

| Name | Description |
|------|-------------|
| `role_assignment_ids` | `key => azurerm_role_assignment.id`. |
| `cosmos_sql_role_assignment_ids` | `key => azapi sqlRoleAssignment.id`. |

## Notes

- Control-plane assignment names are azurerm-generated (state-tracked
  idempotency). Cosmos SQL assignment names are a deterministic `uuidv5` over the
  account+role+principal triple so re-runs are idempotent.
- `principal_type` defaults to `ServicePrincipal` in the consuming stack (all
  grantees are Foundry system-assigned managed identities).
