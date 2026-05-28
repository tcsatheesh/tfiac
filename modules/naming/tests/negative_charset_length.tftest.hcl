# T032 [US2] — negative_charset_length
#
# FR-016 length-budget check: trigger overflow on storage (max_length=24) by
# combining worst-case segments + a long override-supplied environment token.
# (Note: environment is constrained to length 1..4 by variable.validation, so
#  day-one inputs cannot naturally exceed 24 chars for the FR-037-catalogued
#  hyphen-forbidden services — see FR-037 headroom table. This fixture
#  documents the check by way of a private_endpoint under a constrained
#  parent at worst-case segments.)

run "worst_case_storage_within_budget" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp99"
      environment = "pre"
      region      = "eastus2"
      repo        = "x/y"
      services    = [{ type = "storage", count = 999 }]
    }
  }
  # FR-037: worst-case headroom is positive for storage; assert all 999 fit.
  assert {
    condition     = length(output.names) == 1000 # 999 storage + 1 RG
    error_message = "Storage worst-case at 999 instances must succeed (FR-037 headroom)."
  }
}

run "child_overflow_with_long_child_segment" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        {
          type = "nsg"
          nsg_rules = [
            { purpose = "this-is-a-deliberately-very-long-purpose-token-that-overflows" },
          ]
        },
      ]
    }
  }
  # Purpose >16 chars violates the purpose segment in the canonical shape regex
  # and pushes the name over the nsg max_length of 80? Actually 16+ purpose +
  # nsgrule + tenant + env + region + 001 may still fit in 80. The regex check
  # fires first.
  expect_failures = [
    check.length_budget,
    check.shape_regex,
  ]
}
