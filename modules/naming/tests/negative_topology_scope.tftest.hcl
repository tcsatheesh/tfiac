# T031 [US2] — negative_topology_scope (FR-033)

run "dns_in_hub_npd_fails" {
  command = plan
  variables {
    input = {
      topology    = "hub"
      tenant      = "hub"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "dns_zone" }]
    }
  }
  expect_failures = [check.topology_scope]
}

run "firewall_in_spoke_fails" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "firewall" }]
    }
  }
  expect_failures = [check.topology_scope]
}

run "function_app_in_hub_fails" {
  command = plan
  variables {
    input = {
      topology    = "hub"
      tenant      = "hub"
      environment = "prd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "function_app" }]
    }
  }
  expect_failures = [check.topology_scope]
}
