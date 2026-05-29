# T029 [US2] - reordering custom_zones is a no-op (FR-027, set semantics).

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

run "order_a" {
  command = plan

  variables {
    custom_zones = ["a.example.com", "b.example.com"]
  }
}

run "order_b" {
  command = plan

  variables {
    custom_zones = ["b.example.com", "a.example.com"]
  }

  assert {
    condition     = jsonencode(run.order_a.zone_names) == jsonencode(output.zone_names)
    error_message = "FR-027 / SC-002: reordering custom_zones must produce identical zone_names map."
  }
}
