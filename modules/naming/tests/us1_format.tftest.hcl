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
    { service_type = "resource_group", key = "main" },
    { service_type = "vnet", service_purpose = "net", key = "core" },
    { service_type = "storage", service_purpose = "lgs", key = "audit" },
    { service_type = "keyvault", service_purpose = "app", key = "primary" },
    { service_type = "log_analytics", service_purpose = "obs", key = "primary" },
  ]
  children = []
}

# US1 / SC-001 / INV-7 - canonical names match the expected shape per service_type.

run "rg_hyphenated_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "rg-net-shd-hub-prd-uks-001")
    error_message = "Expected RG name 'rg-net-shd-hub-prd-uks-001' in output.names; got: ${jsonencode(keys(output.names))}"
  }

  assert {
    condition     = output.names["rg-net-shd-hub-prd-uks-001"].service_type == "resource_group"
    error_message = "RG entry should carry service_type=resource_group."
  }

  assert {
    condition     = output.names["rg-net-shd-hub-prd-uks-001"].azure_max == 90
    error_message = "RG azure_max should be 90."
  }
}

run "vnet_hyphenated_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "vnet-net-shd-hub-prd-uks-001")
    error_message = "Expected vnet-net-shd-hub-prd-uks-001 in output.names; got: ${jsonencode(keys(output.names))}"
  }

  assert {
    condition     = output.names["vnet-net-shd-hub-prd-uks-001"].azure_max == 64
    error_message = "vnet azure_max should be 64."
  }
}

run "storage_concatenated_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "stlgsshdhubprduks001")
    error_message = "Expected concatenated storage name 'stlgsshdhubprduks001'; got: ${jsonencode(keys(output.names))}"
  }

  assert {
    condition     = output.names["stlgsshdhubprduks001"].azure_max == 24
    error_message = "storage azure_max should be 24."
  }

  assert {
    condition     = length([for k, _ in output.names : k if startswith(k, "stlgs")][0]) <= 24
    error_message = "storage name length should fit azure_max=24."
  }
}

run "keyvault_concatenated_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "kvappshdhubprduks001")
    error_message = "Expected keyvault name 'kvappshdhubprduks001'; got: ${jsonencode(keys(output.names))}"
  }
}

run "log_analytics_hyphenated_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "log-obs-shd-hub-prd-uks-001")
    error_message = "Expected log_analytics name 'log-obs-shd-hub-prd-uks-001'; got: ${jsonencode(keys(output.names))}"
  }
}
