# T020 [US1] - catalogue invariants: 25 entries, all keys pass FR-012, all
# FQDNs pass FR-016. Operates entirely on local.catalogue (plan-time known).

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

run "catalogue_has_25_entries" {
  command = plan

  assert {
    condition     = length(output.zone_names) == 25
    error_message = "Catalogue (with empty custom_zones / disable_catalogue_zones) must surface exactly 25 zone_names entries; got ${length(output.zone_names)}."
  }
}

run "catalogue_keys_match_fr012" {
  command = plan

  assert {
    condition = alltrue([
      for k in keys(output.zone_names) :
      can(regex("^[a-z][a-z0-9-]{1,15}$", k))
    ])
    error_message = "FR-012 / DNS-INV-1: every catalogue key must match ^[a-z][a-z0-9-]{1,15}$. Offending: ${jsonencode([
      for k in keys(output.zone_names) : k if !can(regex("^[a-z][a-z0-9-]{1,15}$", k))
    ])}."
  }
}

run "catalogue_fqdns_match_fr016" {
  command = plan

  assert {
    condition = alltrue([
      for f in values(output.zone_names) :
      length(f) <= 253 && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)(\\.([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?))+$", f))
    ])
    error_message = "FR-016: every catalogue FQDN must satisfy the FR-016 regex. Offending: ${jsonencode([
      for f in values(output.zone_names) : f
      if !(length(f) <= 253 && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)(\\.([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?))+$", f)))
    ])}."
  }
}
