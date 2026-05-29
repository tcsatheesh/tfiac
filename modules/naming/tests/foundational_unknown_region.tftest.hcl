variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "xyz" # not in catalogue
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }
  services = []
  children = []
}

run "unknown_region_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
