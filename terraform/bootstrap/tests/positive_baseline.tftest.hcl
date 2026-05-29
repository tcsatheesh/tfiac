###############################################################################
# terraform/bootstrap/tests/positive_baseline.tftest.hcl
#
# Mock-provider plan to ensure the bootstrap stack composes: naming engine
# resolves storage + rg, both resources plan, container plans.
###############################################################################

mock_provider "azurerm" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  region          = "swedencentral"
  repo            = "_github_org/_github_repo"
  environment     = "npd"
  purpose         = "tool"
}

run "bootstrap_plan" {
  command = plan

  assert {
    condition     = startswith(azurerm_resource_group.this.name, "rg-hub-npd-tool-sdc-")
    error_message = "Tooling RG must follow naming convention rg-hub-npd-tool-sdc-NNN."
  }

  assert {
    condition     = startswith(azurerm_storage_account.tfstate.name, "sthubnpdsdc")
    error_message = "Tooling storage account must follow naming convention sthubnpdsdcNNN."
  }

  assert {
    condition     = azurerm_storage_account.tfstate.account_replication_type == "ZRS"
    error_message = "tfstate storage account must use zone-redundant replication."
  }

  assert {
    condition     = azurerm_storage_account.tfstate.shared_access_key_enabled == false
    error_message = "tfstate storage account must disable shared-key auth (Entra-ID only)."
  }

  assert {
    condition     = azurerm_storage_container.tfstate.name == "tfstate"
    error_message = "Container name must be exactly 'tfstate'."
  }
}
