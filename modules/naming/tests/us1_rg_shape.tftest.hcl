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

# INV-4 case (a): RG entry with service_purpose set is forbidden.
run "rg_forbids_service_purpose" {
  command = plan

  variables {
    services = [
      { service_type = "resource_group", service_purpose = "abc", key = "main" },
    ]
  }

  expect_failures = [
    terraform_data.assertions,
  ]
}

# INV-4 case (b): non-RG entry missing service_purpose is forbidden.
run "non_rg_requires_service_purpose" {
  command = plan

  variables {
    services = [
      { service_type = "storage", key = "primary" },
    ]
  }

  expect_failures = [
    terraform_data.assertions,
  ]
}
