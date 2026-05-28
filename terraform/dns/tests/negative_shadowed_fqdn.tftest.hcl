# T024 [US2] — negative_shadowed_fqdn (FR-017)
#
# A custom FQDN that shadows a catalogue zone (privatelink.blob.core.windows.net)
# must hard-fail at plan time via the module RG precondition (T027).

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

run "shadow_blob_fqdn_fails" {
  command = plan

  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "_github_org/_github_repo"
    custom_zones            = ["privatelink.blob.core.windows.net"]
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }

  expect_failures = [
    terraform_data.guard_custom_zones_no_shadow,
  ]
}
