# VC-34 — enabling the account Key Vault grants with no key vault in the
# consumed services state must be rejected by the stack check.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  services_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/dev/services.tfstate"
  }
  enable_aifoundry_keyvault_connection = true
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

# aifoundry present but NO keyvault.
override_data {
  target = data.terraform_remote_state.services
  values = {
    outputs = {
      naming = {
        acct = { service_type = "aifoundry", service_purpose = "fdy" }
      }
      resource_ids = {
        acct = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct"
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

run "reject_keyvault_without_keyvault" {
  command = plan

  expect_failures = [
    check.aifoundry_keyvault_connection_rbac_prereqs,
  ]
}
