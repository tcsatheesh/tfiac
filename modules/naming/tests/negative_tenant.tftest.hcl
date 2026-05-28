# T029 [US2] — negative_tenant
# sp00, sp1, sp100 MUST fail at variable.validation (FR-019).

run "sp00_rejected" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp00"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  expect_failures = [var.input]
}

run "sp1_rejected" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp1"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  expect_failures = [var.input]
}

run "sp100_rejected" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp100"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = [{ type = "vnet" }]
    }
  }
  expect_failures = [var.input]
}
