# T022 - US1 positive baseline for the prd environment.

variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "swc"
    usecase       = "shd"
    stack_purpose = "log"
    repo          = "tcsatheesh/tfiac"
  }
  workspace_key     = "central"
  retention_in_days = 30
  daily_quota_gb    = -1
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "workspace_name_matches_snapshot_prd" {
  command = plan

  assert {
    condition     = jsondecode(file("${path.module}/tests/fixtures/workspace_name_snapshot_prd.json")) == output.workspace_name
    error_message = "workspace_name diverges from workspace_name_snapshot_prd.json. Regenerate per tests/fixtures/README.md if intentional."
  }

  assert {
    condition     = replace(jsondecode(file("${path.module}/tests/fixtures/resource_group_name_snapshot.json")), "<env>", "prd") == output.resource_group_name
    error_message = "resource_group_name (prd) diverges from resource_group_name_snapshot.json."
  }
}
