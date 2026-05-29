variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }
  services = []
  children = []
}

run "engine_version_pinned" {
  command = plan

  assert {
    condition     = output.engine_version == "0.1.0"
    error_message = "engine_version output should be the pinned semver string."
  }
}

run "empty_inputs_yield_empty_map" {
  command = plan

  assert {
    condition     = length(output.names) == 0
    error_message = "With no services and no children, output.names must be empty."
  }
}
