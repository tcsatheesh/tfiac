# Shared test fixture - reference inputs used by every later test.
# NOTE: terraform test does NOT auto-share `variables` or `provider`/`mock_provider`
# blocks across .tftest.hcl files. Each test file must declare its own.
# Keep this file as the canonical reference for what those blocks should contain
# (copy-paste source of truth so they stay in sync).

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

# Mock the cloud providers so plan-time tests don't need Azure credentials.
mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}
