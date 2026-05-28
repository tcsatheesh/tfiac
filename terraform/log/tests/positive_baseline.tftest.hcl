mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

run "baseline_workspace" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    region          = "swedencentral"
    repo            = "tcsatheesh/tfiac"
    topology        = "hub"
    tenant          = "hub"
    environment     = "npd"
  }

  assert {
    condition     = output.workspace_name == "log-hub-npd-sdc-001"
    error_message = "workspace_name must be log-hub-npd-sdc-001."
  }

  assert {
    condition     = output.resource_group_name == "rg-hub-npd-sdc-001"
    error_message = "resource_group_name must be rg-hub-npd-sdc-001."
  }
}
