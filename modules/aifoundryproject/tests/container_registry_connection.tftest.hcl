# FR-063 / C-079 (Amendment 2026-06-05) — project ContainerRegistry connection.
# With container_registry_connection_enabled = true the project module emits ONE
# Microsoft.CognitiveServices/accounts/projects/connections named
# "containerregistry", category=ContainerRegistry, authType=ManagedIdentity,
# isDefault=true, target = the supplied login server. Default off emits none.

variables {
  canonical_name      = "aifp-shd-shd-sp01-dev-uks-001"
  resource_group_name = "rg-svc-shd-sp01-dev-uks-001"
  location            = "uksouth"
  engine_record = {
    service_type    = "aifoundry_project"
    service_purpose = "shd"
    stack_purpose   = null
    parent          = null
    tags = {
      managed_by      = "terraform"
      tenant          = "sp01"
      environment     = "dev"
      region          = "uksouth"
      repo            = "tcsatheesh/tfiac"
      usecase         = "shd"
      stack_purpose   = "svc"
      service_purpose = "shd"
    }
    azure_max = 32
  }
  overrides                         = {}
  shared_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-log-shd-hub-npd-swc-001/providers/Microsoft.OperationalInsights/workspaces/log-shd-shd-hub-npd-swc-001"
  diagnostic_settings_enabled       = true
  parent_account_id                 = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001"
}

mock_provider "azurerm" {}
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.CognitiveServices/accounts/aif-shd-shd-sp01-dev-uks-001/projects/aifp-shd-shd-sp01-dev-uks-001"
    }
  }
}

run "registry_connection_default_off" {
  command = apply

  assert {
    condition     = length(azapi_resource.container_registry_connection) == 0
    error_message = "FR-063: default (container_registry_connection_enabled unset) must emit no ContainerRegistry connection."
  }
}

run "registry_connection_emitted" {
  command = apply

  variables {
    container_registry_connection_enabled = true
    container_registry_login_server       = "crshdshdsp01devuks001.azurecr.io"
    container_registry_id                 = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.ContainerRegistry/registries/crshdshdsp01devuks001"
  }

  assert {
    condition     = length(azapi_resource.container_registry_connection) == 1
    error_message = "FR-063: container_registry_connection_enabled=true must emit exactly one ContainerRegistry connection."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].name == "containerregistry"
    error_message = "FR-063: the registry connection must be named \"containerregistry\"."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].parent_id == azapi_resource.this.id
    error_message = "FR-063: the registry connection parent_id must be the project resource id."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].body.properties.category == "ContainerRegistry"
    error_message = "FR-063: connection category must be \"ContainerRegistry\"."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].body.properties.authType == "ManagedIdentity"
    error_message = "FR-063: connection authType must be \"ManagedIdentity\"."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].body.properties.isDefault == true
    error_message = "FR-063: connection must set isDefault=true (mirrors the azd-provisioned reference)."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].body.properties.target == "crshdshdsp01devuks001.azurecr.io"
    error_message = "FR-063: connection target must be the supplied registry login server."
  }

  assert {
    condition     = azapi_resource.container_registry_connection[0].body.properties.metadata.ResourceId == "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-svc-shd-sp01-dev-uks-001/providers/Microsoft.ContainerRegistry/registries/crshdshdsp01devuks001"
    error_message = "FR-063: connection metadata.ResourceId must be the supplied registry resource id."
  }
}
