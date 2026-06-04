# Shared fixture documentation for the 007-rbac stack tests.
#
# The stack ALWAYS reads the consumed 006-services remote state
# (data.terraform_remote_state.services) and, when the Foundry account/project
# are present, the live principalIds via azapi data sources
# (data.azapi_resource.account[0] / .project[0]). None of those backends is
# reachable inside terraform_test, so every test file in this directory
# MUST `override_data` them inline. Terraform 1.13 does not auto-share
# mock_provider / override_data across .tftest.hcl files; the blocks are
# therefore repeated in each test rather than imported from here. This file
# documents the canonical fixture values and runs a baseline default-off plan.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  services_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/dev/services.tfstate"
  }
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

# Default-off baseline: a stack with only an aifoundry account (no project, no
# BYO targets, toggles off) produces just the account RG Contributor grant.
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

run "baseline_account_only" {
  command = plan

  assert {
    condition     = length(output.role_assignment_ids) == 1
    error_message = "An account-only stack must yield exactly the RG Contributor grant."
  }

  assert {
    condition     = contains(keys(output.role_assignment_ids), "account-rg-contributor")
    error_message = "FR-048 account RG Contributor grant must be present."
  }

  assert {
    condition     = length(output.cosmos_sql_role_assignment_ids) == 0
    error_message = "No cosmos => no SQL data-plane grant."
  }
}
