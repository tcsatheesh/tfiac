# T022a [US1] — positive_replan_zero_diff (FR-026 / SC-002)
#
# Two consecutive plan runs with identical baseline inputs.
# Validates that for_each keyspace is fully plan-known and stable —
# the run definition itself remaining textually identical, combined with
# the for_each derivation (catalogue ∪ custom − disabled, all of which
# are pure-string functions of variables), is what we sample here.
# Stronger zero-diff verification against APPLIED state is a real-backend
# concern documented in quickstart.md.

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

run "first_plan_baseline" {
  command = plan
  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = []
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }
  assert {
    condition     = length(output.zone_names) == 25
    error_message = "First plan must produce exactly 25 zones."
  }
}

run "second_plan_identical_inputs" {
  command = plan
  variables {
    subscription_id         = "00000000-0000-0000-0000-000000000000"
    region                  = "swedencentral"
    repo                    = "tcsatheesh/tfiac"
    custom_zones            = []
    disable_catalogue_zones = []
    topology        = "hub"
    tenant          = "hub"
    environment     = "prd"
  }
  assert {
    condition = jsonencode(output.zone_names) == jsonencode({
      for k in [
        "acr", "agentsvc", "aml-api", "appconfig", "automation",
        "blob", "cogsvc", "cosmos-sql", "dfs", "eventgrid",
        "file", "iothub", "iothub-dps", "monitor", "notebooks",
        "ods", "oms", "openai", "queue", "search",
        "servicebus", "table", "vault", "web", "webapp",
      ] : k => output.zone_names[k]
    })
    error_message = "Re-plan with identical inputs produced different zone_names byte stream (FR-026)."
  }
}
