variables {
  canonical_name      = "kvshdshdsp01npduks001"
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
    service_type    = "keyvault"
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
    azure_max = 24
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "not-a-resource-id"
  diagnostic_settings_enabled       = true
}

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_client_config.current
    values = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000001"
      object_id       = "00000000-0000-0000-0000-000000000002"
      client_id       = "00000000-0000-0000-0000-000000000003"
    }
  }
}

run "regex_rejects_malformed_workspace_id" {
  command         = plan
  expect_failures = [var.shared_log_analytics_workspace_id]
}
