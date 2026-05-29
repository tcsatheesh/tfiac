# T031 [US3] — negative_unknown_disable_key (FR-018)
#
# Unknown catalogue key in disable_catalogue_zones must hard-fail via the
# module RG precondition (T010 primary path).

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

run "unknown_disable_key_rejected" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "_github_org/_github_repo"
    custom_zones            = []
    disable_catalogue_zones = ["frobnicate"]
    topology                = "hub"
    tenant                  = "hub"
    environment             = "prd"
  }

  expect_failures = [
    terraform_data.guard_disable_keys_known,
  ]
}
