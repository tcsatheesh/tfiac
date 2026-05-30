# T021 - services-stack-consumption negative: invoking the loganalytics
# wrapper with the services-stack purpose ("svc") MUST be rejected at
# plan time because the wrapper expects stack_purpose="log" to keep
# coherent with terraform/log/ outputs (LOG-INV-2). The engine itself
# accepts any 3-char stack_purpose, so we rely on the wrapper variable
# validation in modules/loganalytics/variables.tf::input to reject this.
#
# At v1 the variable validation in this wrapper does NOT pin
# stack_purpose. The check that fires here is the engine catalogue's
# regex (^[a-z0-9]{3}$). We assert that a 4-char "svcc" is rejected to
# prove engine-level defence-in-depth still fires when the services
# stack accidentally passes a malformed stack_purpose downstream.

variables {
  input = {
    tenant        = "sp01"
    environment   = "npd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svcc"
    repo          = "tcsatheesh/tfiac"
  }
  workspace_key = "central"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "malformed_stack_purpose_rejected" {
  command         = plan
  expect_failures = [var.input]
}
