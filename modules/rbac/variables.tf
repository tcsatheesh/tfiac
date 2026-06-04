# 007-rbac engine — generic Foundry managed-identity role-assignment fan-out.
#
# This module is intentionally "dumb": it does NOT resolve any target by name,
# read remote state, or know anything about Foundry. The consuming stack
# (terraform/rbac) builds two fully-resolved maps and hands them in. The module
# only fans them out into Azure role assignments (control-plane) and Cosmos DB
# sqlRoleAssignments (data-plane). This keeps it reusable and trivially testable.

variable "role_assignments" {
  description = <<-EOT
    Map of control-plane Azure role assignments to create, keyed by a stable
    caller-chosen id (e.g. "account-keyvault-crypto-user"). Each entry pins the
    target scope, the full role-definition resource id, the grantee principal id
    and its principal type. Empty map => no assignments (default-safe).
  EOT
  type = map(object({
    scope_id           = string
    role_definition_id = string
    principal_id       = string
    principal_type     = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.role_assignments :
      v.scope_id != "" && v.role_definition_id != "" && v.principal_id != ""
    ])
    error_message = "Every role_assignments entry must carry a non-empty scope_id, role_definition_id and principal_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.role_assignments :
      contains(["ServicePrincipal", "User", "Group", "ForeignGroup", "Device"], v.principal_type)
    ])
    error_message = "principal_type must be one of ServicePrincipal, User, Group, ForeignGroup, Device."
  }
}

variable "cosmos_sql_role_assignments" {
  description = <<-EOT
    Map of Cosmos DB data-plane SQL role assignments to create, keyed by a
    stable caller-chosen id. Each entry pins the parent Cosmos account id, the
    full sqlRoleDefinition id and the grantee principal id. Empty map => none.
  EOT
  type = map(object({
    cosmos_account_id      = string
    sql_role_definition_id = string
    principal_id           = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.cosmos_sql_role_assignments :
      v.cosmos_account_id != "" && v.sql_role_definition_id != "" && v.principal_id != ""
    ])
    error_message = "Every cosmos_sql_role_assignments entry must carry a non-empty cosmos_account_id, sql_role_definition_id and principal_id."
  }
}
