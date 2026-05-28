# T048 [US4] — baseline tags present on every record (FR-014)

run "every_record_has_six_baseline_keys" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "_github_org/_github_repo"
      services = [
        { type = "keyvault" },
        { type = "storage", count = 1 },
        { type = "vnet", subnets = [{ purpose = "app" }] },
      ]
    }
  }
  assert {
    condition = alltrue([
      for k, r in output.names :
      alltrue([
        contains(keys(r.tags), "tenant"),
        contains(keys(r.tags), "topology"),
        contains(keys(r.tags), "environment"),
        contains(keys(r.tags), "region"),
        contains(keys(r.tags), "managed_by"),
        contains(keys(r.tags), "repo"),
        r.tags.managed_by == "terraform",
        r.tags.repo == "_github_org/_github_repo",
      ])
    ])
    error_message = "Every emitted record must carry six baseline tag keys with managed_by=terraform and the input.repo value (FR-014)."
  }
}
