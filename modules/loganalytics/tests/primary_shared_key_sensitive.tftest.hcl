# T023 - LOG-INV-10 / FR-106 - workspace primary_shared_key is non-empty (mock
# returns a synthetic value) and exposed through the wrapper module. The
# `sensitive = true` flag itself is structural (declared on the output block);
# terraform test cannot introspect the sensitivity flag directly, so we instead
# assert the value flows through end-to-end and rely on `terraform validate` +
# `grep` to confirm the flag in CI.

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

run "primary_shared_key_flows_through" {
  # primary_shared_key is computed at apply time on the underlying
  # azurerm_log_analytics_workspace resource, so we need a mocked apply (not a
  # plan) for the value to be materialised.
  command = apply

  assert {
    # Touching the value forces the test runner to materialise it; non-null
    # means the chain module.workspace.resource.primary_shared_key wired
    # through to the wrapper output.
    condition     = nonsensitive(output.primary_shared_key) != null
    error_message = "primary_shared_key did not flow through the wrapper module."
  }
}
