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
    {
      service_type    = "storage"
      service_purpose = "lgs"
      key             = "audit"
      extra_tags      = { owner = "platform" }
    },
  ]
  children = []
  extra_tags = {
    cost_center = "PLT-001"
    owner       = "stack-default"
  }
}

run "stack_and_entry_extras_both_present" {
  command = plan

  assert {
    condition = alltrue([
      for _, entry in output.names :
      entry.tags["cost_center"] == "PLT-001"
    ])
    error_message = "Stack-level extra_tags must appear on every entry."
  }

  assert {
    condition = alltrue([
      for _, entry in output.names :
      entry.tags["owner"] == "platform"
    ])
    error_message = "Per-entry extra_tags must override stack-level extra_tags for the same key."
  }
}
