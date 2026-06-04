# Default-safe — empty maps create zero resources (VC-31 at the module level).

mock_provider "azurerm" {}
mock_provider "azapi" {}

run "creates_nothing" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.this) == 0
    error_message = "Empty role_assignments must create no control-plane assignments."
  }

  assert {
    condition     = length(azapi_resource.cosmos_sql) == 0
    error_message = "Empty cosmos_sql_role_assignments must create no SQL assignments."
  }
}
