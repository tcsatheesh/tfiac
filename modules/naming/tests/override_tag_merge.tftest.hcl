# T049 [US4] — override-merged tag (FR-013, FR-014)

run "override_adds_cost_center" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "_github_org/_github_repo"
      services    = [{ type = "storage", count = 1 }]
      overrides = {
        "stsp01npduks001" = { tags = { cost_center = "ABC123" } }
      }
    }
  }
  assert {
    condition = (
      contains(keys(output.names["stsp01npduks001"].tags), "cost_center") &&
      output.names["stsp01npduks001"].tags.cost_center == "ABC123" &&
      length(keys(output.names["stsp01npduks001"].tags)) == 7
    )
    error_message = "Override-supplied cost_center must merge into baseline tags to yield 7 keys (FR-013)."
  }
}
