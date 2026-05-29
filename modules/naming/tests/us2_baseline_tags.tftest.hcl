variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }
  services = [
    { service_type = "resource_group", key = "main" },
    { service_type = "vnet", service_purpose = "net", key = "core" },
  ]
  children = []
}

run "baseline_tags_present_on_every_entry" {
  command = plan

  assert {
    condition = alltrue([
      for name, entry in output.names :
      length(setintersection(
        toset(keys(entry.tags)),
        toset(["tenant", "environment", "region", "managed_by", "repo", "usecase", "stack_purpose", "service_purpose"])
      )) == 8
    ])
    error_message = "Every output entry must carry all 8 baseline tag keys; got: ${jsonencode({ for n, e in output.names : n => keys(e.tags) })}"
  }
}

run "region_tag_is_full_name_not_short_code" {
  command = plan

  assert {
    condition = alltrue([
      for _, entry in output.names :
      entry.tags["region"] == "uksouth"
    ])
    error_message = "region tag must be the full Azure region name ('uksouth'), not the short code ('uks')."
  }
}

run "managed_by_is_terraform_constant" {
  command = plan

  assert {
    condition = alltrue([
      for _, entry in output.names :
      entry.tags["managed_by"] == "terraform"
    ])
    error_message = "managed_by tag must be the constant 'terraform'."
  }
}

run "repo_tag_preserves_case" {
  command = plan

  variables {
    input = {
      tenant        = "hub"
      environment   = "prd"
      region        = "uks"
      usecase       = "shd"
      stack_purpose = "svc"
      repo          = "TcSatheesh/TFIaC" # case-preserving
    }
  }

  assert {
    condition = alltrue([
      for _, entry in output.names :
      entry.tags["repo"] == "TcSatheesh/TFIaC"
    ])
    error_message = "repo tag must be preserved verbatim (case-sensitive)."
  }
}
