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
    { service_type = "storage", service_purpose = "lgs", key = "dup" },
    { service_type = "storage", service_purpose = "lgs", key = "dup" },
  ]
  children = []
}

# INV-2: two entries sharing (service_type, service_purpose, key) must fail.
run "duplicate_key_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
