# T030 [US2] — negative_region (FR-018)

run "unknown_region" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "marsone"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  expect_failures = [
    check.region_known,
    check.shape_regex,
  ]
}
