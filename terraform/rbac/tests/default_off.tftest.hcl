# VC-31 — default-safe. No targets present and toggles off => zero grants.

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

# An empty services stack (no aifoundry, no targets) => nothing to grant.
override_data {
  target = data.terraform_remote_state.services
  values = {
    outputs = {
      naming            = {}
      resource_ids      = {}
      resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg"
    }
  }
}

run "no_targets_no_grants" {
  command = plan

  assert {
    condition     = length(output.role_assignment_ids) == 0
    error_message = "VC-31: no targets must produce zero control-plane grants."
  }

  assert {
    condition     = length(output.cosmos_sql_role_assignment_ids) == 0
    error_message = "VC-31: no cosmos must produce zero SQL data-plane grants."
  }
}
