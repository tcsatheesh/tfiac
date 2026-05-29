# T023 [US1] - the engine-emitted RG name follows FR-009 / the engine's
# rg_hyphenated shape with the wrapper's `usecase="shd"` / `stack_purpose="dns"`
# constants and the FR-001-pinned scope (hub/prd/swc). Resulting name:
#   rg-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}
#   = rg-dns-shd-hub-prd-swc-001

variables {
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  region                  = "swc"
  repo                    = "tcsatheesh/tfiac"
  topology                = "hub"
  tenant                  = "hub"
  environment             = "prd"
  custom_zones            = []
  disable_catalogue_zones = []
}

mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

run "rg_canonical_name" {
  command = plan

  assert {
    condition     = output.resource_group_name == "rg-dns-shd-hub-prd-swc-001"
    error_message = "Expected resource_group_name == \"rg-dns-shd-hub-prd-swc-001\"; got ${output.resource_group_name}."
  }
}
