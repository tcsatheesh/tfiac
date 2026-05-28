# T043 [US3] — region_code uniqueness (FR-010)
# The region_codes table MUST have unique short codes (asserted by check.region_code_uniqueness).

run "region_codes_unique" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = []
    }
  }
  assert {
    condition     = length(output.names) >= 1
    error_message = "Engine must succeed with catalogue intact (FR-010 uniqueness invariant)."
  }
}
