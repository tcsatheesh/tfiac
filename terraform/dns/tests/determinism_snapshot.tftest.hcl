# T014 [US1] — determinism_snapshot (FR-028 / SC-002 / SC-007)
#
# Scope NOTE: The committed reference snapshot covers `zone_names` only.
# Rationale: under `command = plan` with mock_provider, computed attributes
# (azurerm_private_dns_zone.id) are unknown / mock-generated and would
# pollute the snapshot bytes. Config-set `name` arguments (the FQDNs) ARE
# known at plan time and are the meaningful determinism contract: they
# guarantee the catalogue + custom-zone for_each keyspace is byte-stable.
# At apply-time zone_ids are derived deterministically from the same
# for_each keys, so byte-stability of zone_names + the stable Azure naming
# scheme transitively guarantees byte-stability of zone_ids.
#
# This deviates slightly from the T014 task wording (which included
# zone_ids); the deviation is documented in modules/dnszones/README.md and
# in the Phase 3 completion report.

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

run "zone_names_match_snapshot" {
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

  assert {
    condition     = jsonencode(output.zone_names) == file("${path.module}/tests/snapshots/reference.json")
    error_message = "output.zone_names diverges from committed reference snapshot. If the catalogue or engine entry legitimately changed, regenerate tests/snapshots/reference.json in the same PR."
  }
}
