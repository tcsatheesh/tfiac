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
}

# US3 / SC-003: reordering the services list must NOT change output.names.
# We run twice with the same set in different orders and compare jsonencode
# (which sorts map keys, so byte-equal proves both key set AND values match).

run "order_a" {
  command = plan

  variables {
    services = [
      { service_type = "resource_group", key = "main" },
      { service_type = "storage", service_purpose = "lgs", key = "audit" },
      { service_type = "storage", service_purpose = "lgs", key = "events" },
      { service_type = "keyvault", service_purpose = "app", key = "primary" },
      { service_type = "vnet", service_purpose = "net", key = "core" },
    ]
  }

  assert {
    condition     = length(output.names) == 5
    error_message = "Expected 5 entries in order_a; got ${length(output.names)}."
  }
}

run "order_b" {
  command = plan

  variables {
    services = [
      { service_type = "vnet", service_purpose = "net", key = "core" },
      { service_type = "keyvault", service_purpose = "app", key = "primary" },
      { service_type = "storage", service_purpose = "lgs", key = "events" },
      { service_type = "resource_group", key = "main" },
      { service_type = "storage", service_purpose = "lgs", key = "audit" },
    ]
  }

  # Cross-run reference: run.order_a.<output_name> exposes order_a's outputs.
  assert {
    condition     = jsonencode(output.names) == jsonencode(run.order_a.names)
    error_message = "output.names must be byte-identical regardless of services list order (SC-003)."
  }
}
