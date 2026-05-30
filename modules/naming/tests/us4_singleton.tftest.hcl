variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "net"
    repo          = "tcsatheesh/tfiac"
  }
  services = [
    { service_type = "vnet", service_purpose = "net", key = "core" },
  ]
  children = [
    { service_type = "vnet_bastion", parent_key = "core", key = "bas" },
    { service_type = "vnet_firewall", parent_key = "core", key = "afw" },
  ]
}

run "singletons_produce_expected_names" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "bas-vnet-net-shd-hub-prd-uks-001")
    error_message = "Expected vnet_bastion singleton name; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "bas-")])}"
  }

  assert {
    condition     = contains(keys(output.names), "afw-vnet-net-shd-hub-prd-uks-001")
    error_message = "Expected vnet_firewall singleton name."
  }
}

# INV-5: a second singleton of the same type on the same parent must fail.
run "duplicate_singleton_fails" {
  command = plan

  variables {
    children = [
      { service_type = "vnet_bastion", parent_key = "core", key = "bas1" },
      { service_type = "vnet_bastion", parent_key = "core", key = "bas2" },
    ]
  }

  expect_failures = [
    terraform_data.assertions,
  ]
}
