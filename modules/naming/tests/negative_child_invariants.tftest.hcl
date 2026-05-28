# T033 [US2] — negative_child_invariants

run "duplicate_subnet_purpose" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [{
        type = "vnet"
        subnets = [
          { purpose = "app" },
          { purpose = "app" },
        ]
      }]
    }
  }
  expect_failures = [
    check.purpose_unique_per_parent,
  ]
}

run "pe_unresolved_subnet" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        { type = "storage", count = 1, private_endpoints = [{ subnet = "snet-nonexistent" }] },
      ]
    }
  }
  expect_failures = [check.pe_subnet_resolves]
}

run "child_only_at_top_level" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "subnet" }]
    }
  }
  expect_failures = [
    check.service_type_known,
    check.child_only_not_at_top_level,
    check.shape_regex,
  ]
}

run "unmatched_override_key" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
      overrides   = { "vnet-WRONG-001" = { x = 1 } }
    }
  }
  expect_failures = [check.overrides_match_emitted]
}

run "instance_cap_exceeded" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "storage", count = 1000 }]
    }
  }
  expect_failures = [check.instance_cap]
}
