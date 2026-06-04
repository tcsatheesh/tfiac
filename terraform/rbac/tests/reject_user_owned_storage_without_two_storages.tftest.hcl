# VC-33 — enabling the account user-owned-storage grant with only ONE storage
# (and missing account_storage_purpose) must be rejected by the stack check.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  services_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/dev/services.tfstate"
  }
  enable_aifoundry_user_owned_storage = true
  agent_storage_purpose               = "agt"
  # account_storage_purpose intentionally omitted (null).
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

override_data {
  target = data.terraform_remote_state.services
  values = {
    outputs = {
      naming = {
        acct  = { service_type = "aifoundry", service_purpose = "fdy" }
        stagt = { service_type = "storage", service_purpose = "agt" }
      }
      resource_ids = {
        acct  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct"
        stagt = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/stagt"
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

run "reject_uos_without_two_storages" {
  command = plan

  expect_failures = [
    check.aifoundry_user_owned_storage_rbac_prereqs,
  ]
}
