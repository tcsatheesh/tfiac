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
    { service_type = "nsg", service_purpose = "net", key = "web" },
    { service_type = "route_table", service_purpose = "net", key = "main" },
    { service_type = "apim", service_purpose = "api", key = "primary" },
  ]
  children = [
    { service_type = "subnet",   parent_key = "core", child_purpose = "app",     key = "app" },
    { service_type = "subnet",   parent_key = "core", child_purpose = "pep",     key = "pep" },
    { service_type = "nsg_rule", parent_key = "web",  child_purpose = "allow80", key = "http" },
    { service_type = "route",    parent_key = "main", child_purpose = "default", key = "def" },
    { service_type = "apim_api", parent_key = "primary", child_purpose = "users", key = "u" },
  ]
}

# US4: child_purpose-shape names follow {abbr}-{child_purpose}-{P}
# where {P} is the parent's hyphenated tuple.

run "subnet_uses_parent_hyphenated_tuple" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "snet-app-vnet-net-shd-hub-prd-uks-001")
    error_message = "Expected subnet name 'snet-app-vnet-net-shd-hub-prd-uks-001'; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "snet-")])}"
  }

  assert {
    condition     = contains(keys(output.names), "snet-pep-vnet-net-shd-hub-prd-uks-001")
    error_message = "Expected second subnet name 'snet-pep-vnet-net-shd-hub-prd-uks-001'."
  }

  assert {
    condition     = output.names["snet-app-vnet-net-shd-hub-prd-uks-001"].parent == "vnet-net-shd-hub-prd-uks-001"
    error_message = "Subnet's parent field must hold the parent's canonical name."
  }
}

run "nsg_rule_route_apim_api_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "nsgrule-allow80-nsg-net-shd-hub-prd-uks-001")
    error_message = "Expected nsg_rule name; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "nsgrule-")])}"
  }

  assert {
    condition     = contains(keys(output.names), "udr-default-rt-net-shd-hub-prd-uks-001")
    error_message = "Expected route (udr) name; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "udr-")])}"
  }

  assert {
    condition     = contains(keys(output.names), "api-users-apim-api-shd-hub-prd-uks-001")
    error_message = "Expected apim_api name; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "api-")])}"
  }
}
