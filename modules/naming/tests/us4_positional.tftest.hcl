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
    { service_type = "storage", service_purpose = "lgs", key = "audit" },
  ]
  children = [
    { service_type = "private_endpoint", parent_key = "audit", key = "blob" },
    { service_type = "private_endpoint", parent_key = "audit", key = "queue" },
    { service_type = "private_endpoint", parent_key = "audit", key = "table" },
    { service_type = "diagnostic_setting", parent_key = "audit", key = "law" },
  ]
}

# US4 positional: numbering is per (child_type, parent) sorted by key.
# Sorted keys: blob, queue, table → 001, 002, 003.
# Parent's hyphenated tuple for `storage`: "st-lgs-shd-hub-prd-uks-001".

run "private_endpoints_number_positionally" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "pep-st-lgs-shd-hub-prd-uks-001-001")
    error_message = "Expected pep-...-001 for sorted-first key 'blob'; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "pep-")])}"
  }

  assert {
    condition     = contains(keys(output.names), "pep-st-lgs-shd-hub-prd-uks-001-002")
    error_message = "Expected pep-...-002 for sorted-second key 'queue'."
  }

  assert {
    condition     = contains(keys(output.names), "pep-st-lgs-shd-hub-prd-uks-001-003")
    error_message = "Expected pep-...-003 for sorted-third key 'table'."
  }
}

run "diagnostic_setting_positional_shape" {
  command = plan

  assert {
    condition     = contains(keys(output.names), "diag-st-lgs-shd-hub-prd-uks-001-001")
    error_message = "Expected diag-...-001 positional name; got: ${jsonencode([for k in keys(output.names) : k if startswith(k, "diag-")])}"
  }
}
