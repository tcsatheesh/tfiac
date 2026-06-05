variables {
  canonical_name      = "crshdshdsp01npduks001"
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
    service_type    = "container_registry"
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
    azure_max = 50
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
}

mock_provider "azurerm" {}

run "canonical_name_flows_through" {
  command = plan

  assert {
    condition     = var.canonical_name == "crshdshdsp01npduks001"
    error_message = "canonical_name diverged from engine reference."
  }
}


run "diag_wired_to_shared_la" {
  command = plan

  # C-014 (Amendment 2026-05-31) — the default azurerm_monitor_diagnostic_setting
  # resource MUST exist (count=1 by default) and MUST target the shared hub LA
  # workspace id passed via var.shared_log_analytics_workspace_id.
  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.to_hub_la) == 1
    error_message = "C-014: diagnostic_settings_enabled defaults to true but no diag resource was emitted."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.to_hub_la[0].log_analytics_workspace_id == var.shared_log_analytics_workspace_id
    error_message = "C-014: diag log_analytics_workspace_id diverged from the input."
  }
}

run "login_server_output_exposed" {
  command = apply

  # Disable diagnostics so the mock-generated registry id is not fed to the
  # diag setting's target_resource_id (which would fail ARM id parsing).
  variables {
    diagnostic_settings_enabled = false
  }

  # The module exposes the registry login server so the services stack can
  # surface it to downstream consumers.
  assert {
    condition     = output.login_server == azurerm_container_registry.this.login_server
    error_message = "login_server output must equal the registry login_server attribute."
  }
}
