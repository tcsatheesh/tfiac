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
  ]
  children = []
}

# RG entries: service_purpose tag value should equal the entry's stack_purpose
# (per spec.md "Baseline Tags": "RG record uses stack_purpose").
run "rg_service_purpose_tag_uses_stack_purpose" {
  command = plan

  assert {
    condition = output.names["rg-net-shd-hub-prd-uks-001"].tags["service_purpose"] == "net"
    error_message = "RG service_purpose tag must equal the stack_purpose ('net')."
  }

  assert {
    condition = output.names["rg-net-shd-hub-prd-uks-001"].tags["stack_purpose"] == "net"
    error_message = "RG stack_purpose tag must be set to the resolved stack_purpose."
  }
}
