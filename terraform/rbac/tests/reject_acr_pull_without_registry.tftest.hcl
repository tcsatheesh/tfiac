# VC-38 (FR-064) — enabling the project AcrPull grant with no container registry
# in the consumed services state must be rejected by the stack check.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  services_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/dev/services.tfstate"
  }
  enable_project_acr_pull = true
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

# aifoundry account + project present but NO container registry.
override_data {
  target = data.terraform_remote_state.services
  values = {
    outputs = {
      naming = {
        acct = { service_type = "aifoundry", service_purpose = "fdy" }
        proj = { service_type = "aifoundry_project", service_purpose = "prj" }
      }
      resource_ids = {
        acct = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct"
        proj = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct/projects/proj"
      }
      resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg"
    }
  }
}

override_data {
  target = data.azapi_resource.account[0]
  values = {
    output = { identity = { principalId = "11111111-1111-1111-1111-111111111111" } }
  }
}

override_data {
  target = data.azapi_resource.project[0]
  values = {
    output = { identity = { principalId = "22222222-2222-2222-2222-222222222222" } }
  }
}

run "reject_acr_pull_without_registry" {
  command = plan

  expect_failures = [
    check.project_acr_pull_rbac_prereqs,
  ]
}
