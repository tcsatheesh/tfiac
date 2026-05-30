variables {
  canonical_name      = "oai-shd-shd-sp01-npd-uks-001"
  resource_group_name = "rg-svc-shd-sp01-npd-uks-001"
  location            = "uksouth"
  tags = {
    managed_by      = "terraform"
    tenant          = "sp01"
    environment     = "npd"
    region          = "uksouth"
    repo            = "tcsatheesh/tfiac"
    usecase         = "shd"
    stack_purpose   = "svc"
    service_purpose = "shd"
  }
  engine_record = {
    service_type    = "openai"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags = {
      managed_by      = "terraform"
      tenant          = "sp01"
      environment     = "npd"
      region          = "uksouth"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "shd"
    }
    azure_max = 64
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "not-a-resource-id"
  diagnostic_settings_enabled       = true
}

mock_provider "azurerm" {}

run "regex_rejects_malformed_workspace_id" {
  command         = plan
  expect_failures = [var.shared_log_analytics_workspace_id]
}
