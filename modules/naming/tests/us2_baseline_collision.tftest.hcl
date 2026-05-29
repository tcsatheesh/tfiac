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
    { service_type = "storage", service_purpose = "lgs", key = "audit" },
  ]
  children = []
  extra_tags = {
    environment = "ovr" # collides with baseline
  }
}

# INV-8: stack-level extra_tags must not collide with baseline keys.
run "extra_tags_collision_with_baseline_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
