variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }
  children = []
  # 1000 entries in the same (service_type, service_purpose) group
  # triggers INV-3 (>999 per group).
  services = [
    for i in range(1000) : {
      service_type    = "storage"
      service_purpose = "ovf"
      key             = format("k%04d", i)
    }
  ]
}

run "instance_overflow_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
