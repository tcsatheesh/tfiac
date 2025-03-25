data "azuread_service_principal" "deployment_service_principal" {
  for_each     = tomap(var.rbac.service_principals)
  display_name = each.value
}
