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
    { service_type = "storage", service_purpose = "lgs", key = "audit" },
  ]
  children = [
    # PEP attached to a concatenated-shape parent (storage) - the child's {P}
    # slot MUST still be the parent's HYPHENATED tuple per spec.
    { service_type = "private_endpoint", parent_key = "audit", key = "blob" },
  ]
}

run "pep_uses_parent_hyphenated_tuple_even_when_parent_is_concatenated" {
  command = plan

  # Parent's canonical name is concatenated: "stlgsshdhubprduks001".
  # Parent's tuple-for-children is hyphenated: "st-lgs-shd-hub-prd-uks-001".
  # Therefore the PEP name uses the hyphenated form.

  assert {
    condition     = contains(keys(output.names), "stlgsshdhubprduks001")
    error_message = "Parent storage canonical name should be concatenated; got: ${jsonencode(keys(output.names))}"
  }

  assert {
    condition     = contains(keys(output.names), "pep-st-lgs-shd-hub-prd-uks-001-001")
    error_message = "PEP must use the parent's hyphenated tuple as {P}, not the concatenated canonical name."
  }

  assert {
    condition     = output.names["pep-st-lgs-shd-hub-prd-uks-001-001"].parent == "stlgsshdhubprduks001"
    error_message = "PEP's `parent` field still holds the parent's actual canonical name (concatenated)."
  }
}
