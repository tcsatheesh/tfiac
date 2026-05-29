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
    { service_type = "widget", service_purpose = "abc", key = "x" },
  ]
  children = []
}

run "unknown_service_type_fails" {
  command = plan

  expect_failures = [
    terraform_data.assertions,
  ]
}
