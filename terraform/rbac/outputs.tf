output "role_assignment_ids" {
  description = "Map of caller-key => Azure role assignment resource id (control-plane grants)."
  value       = module.rbac.role_assignment_ids
}

output "cosmos_sql_role_assignment_ids" {
  description = "Map of caller-key => Cosmos DB SQL role assignment resource id (data-plane grant)."
  value       = module.rbac.cosmos_sql_role_assignment_ids
}

# Resolved grant scopes (caller-key => target scope id). Lets operators (and the
# test suite, VC-32) confirm each grant landed on the intended target without
# inspecting state.
output "grant_scopes" {
  description = "Map of caller-key => the Azure resource id each control-plane grant is scoped to."
  value       = { for k, v in local.role_assignments : k => v.scope_id }
}

# Resolved grant role-definition ids (caller-key => role_definition_id). Lets the
# test suite (VC-36) confirm a grant carries the intended role GUID.
output "grant_role_definition_ids" {
  description = "Map of caller-key => the role_definition_id each control-plane grant uses."
  value       = { for k, v in local.role_assignments : k => v.role_definition_id }
}
