# T015 [US1] — positive_topology
# Cross-product of (topology × tenant × environment) plus minimal-input
# sub-run (FR-039).

run "hub_hub_npd" {
  command = plan
  variables {
    input = {
      topology    = "hub"
      tenant      = "hub"
      environment = "npd"
      region      = "uksouth"
      repo        = "tcsatheesh/tfiac"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "vnet-hub-npd-uks-001")
    error_message = "hub/hub/npd batch missing canonical vnet."
  }
}

run "spoke_sp99_prd" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp99"
      environment = "prd"
      region      = "uksouth"
      repo        = "tcsatheesh/tfiac"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "rg-sp99-prd-uks-001")
    error_message = "spoke/sp99/prd batch missing canonical RG."
  }
}

run "spoke_sp01_pre" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "pre"
      region      = "uksouth"
      repo        = "tcsatheesh/tfiac"
      services    = [{ type = "vnet" }]
    }
  }
  assert {
    condition     = contains(keys(output.names), "vnet-sp01-pre-uks-001")
    error_message = "spoke/sp01/pre batch missing canonical vnet."
  }
}

# F9 — minimal-input sub-run: services = [] MUST produce only the RG (FR-039).
run "minimal_empty_services" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "tcsatheesh/tfiac"
      services    = []
    }
  }
  assert {
    condition     = length(output.names) == 1
    error_message = "Empty services[] must emit exactly one record (the resource group)."
  }
  assert {
    condition     = output.names["rg-sp01-npd-uks-001"].service_type == "resource_group"
    error_message = "Empty services[] must emit the per-stack RG canonical (FR-025 / FR-039)."
  }
}
