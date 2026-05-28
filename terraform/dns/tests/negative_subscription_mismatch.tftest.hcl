# T035 [US4] — negative_subscription_mismatch (FR-029)
#
# The check.subscription_pinned block must fail when the provider's
# authenticated subscription differs from var.subscription_id.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      tenant_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      object_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      client_id       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
    }
  }
}

run "subscription_mismatch_fails" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "_github_org/_github_repo"
    custom_zones            = []
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }

  expect_failures = [
    check.subscription_pinned,
  ]
}
