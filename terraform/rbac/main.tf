module "rbac" {
  source = "../../modules/rbac"

  role_assignments            = local.role_assignments
  cosmos_sql_role_assignments = local.cosmos_sql_role_assignments
}
