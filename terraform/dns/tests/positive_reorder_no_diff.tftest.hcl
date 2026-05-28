# T028a [US2] — positive_reorder_no_diff (FR-027)
#
# Set-semantics: reordering custom_zones must not change the for_each
# keyspace. Both runs produce the same zone_names byte stream.

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

run "first_plan_ab_order" {
  command = plan
  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = ["a.example.com", "b.example.com"]
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }
  assert {
    condition     = length(output.zone_names) == 27
    error_message = "Expected 25 catalogue + 2 custom = 27 zones."
  }
}

run "second_plan_ba_order_same_keyspace" {
  command = plan
  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = ["b.example.com", "a.example.com"]
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }
  assert {
    condition     = output.zone_names["a.example.com"] == "a.example.com" && output.zone_names["b.example.com"] == "b.example.com"
    error_message = "Reordered custom_zones must yield identical keyspace (FR-027)."
  }
  assert {
    condition     = length(output.zone_names) == 27
    error_message = "Reordered run must produce same number of zones."
  }
}
