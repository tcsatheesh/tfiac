# T028 [US2] — negative_service_type
# Unknown service_type MUST hard-fail at plan time with FR-017 message.

run "unknown_service_type" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "frobnicate" }]
    }
  }
  expect_failures = [
    check.service_type_known,
    check.shape_regex,
  ]
}
