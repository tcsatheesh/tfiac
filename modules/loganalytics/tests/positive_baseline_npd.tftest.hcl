# T021 - US1 positive baseline for the npd environment. Asserts the engine
# emits the workspace name locked in the committed snapshot fixture (FR-110,
# LOG-INV-11).

variables {
  input = {
    tenant        = "hub"
    environment   = "npd"
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

run "workspace_name_matches_snapshot_npd" {
  command = plan

  assert {
    condition     = jsondecode(file("${path.module}/tests/fixtures/workspace_name_snapshot_npd.json")) == output.workspace_name
    error_message = "workspace_name diverges from workspace_name_snapshot_npd.json. Regenerate per tests/fixtures/README.md if intentional."
  }

  assert {
    condition     = replace(jsondecode(file("${path.module}/tests/fixtures/resource_group_name_snapshot.json")), "<env>", "npd") == output.resource_group_name
    error_message = "resource_group_name (npd) diverges from resource_group_name_snapshot.json."
  }
}
