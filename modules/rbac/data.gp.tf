data "azuread_group" "development_team" {
  for_each         = tomap(var.rbac.groups)
  display_name     = each.value
  security_enabled = true
}
