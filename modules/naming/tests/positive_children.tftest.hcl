# T017 [US1] — positive_children
# vnet+subnets (purpose-keyed), nsg+rules (purpose-keyed),
# storage+private_endpoints (positional, parent-by-reference).

run "vnet_with_subnets" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        {
          type = "vnet"
          subnets = [
            { purpose = "app" },
            { purpose = "data" },
            { purpose = "mgmt" },
          ]
        },
      ]
    }
  }
  assert {
    condition = alltrue([
      contains(keys(output.names), "snet-app-sp01-npd-uks-001"),
      contains(keys(output.names), "snet-data-sp01-npd-uks-001"),
      contains(keys(output.names), "snet-mgmt-sp01-npd-uks-001"),
    ])
    error_message = "Expected three purpose-keyed subnets under vnet-sp01-npd-uks-001."
  }
  assert {
    condition     = output.names["snet-app-sp01-npd-uks-001"].parent == "vnet-sp01-npd-uks-001"
    error_message = "subnet.parent must resolve to vnet canonical (FR-030)."
  }
}

run "nsg_with_rules" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        {
          type = "nsg"
          nsg_rules = [
            { purpose = "allow-https" },
            { purpose = "deny-rdp" },
          ]
        },
      ]
    }
  }
  assert {
    condition = alltrue([
      contains(keys(output.names), "nsgrule-allow-https-sp01-npd-uks-001"),
      contains(keys(output.names), "nsgrule-deny-rdp-sp01-npd-uks-001"),
    ])
    error_message = "Expected two purpose-keyed nsg rules."
  }
}

run "storage_with_pes" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        {
          type = "vnet"
          subnets = [
            { purpose = "app" },
            { purpose = "data" },
          ]
        },
        {
          type  = "storage"
          count = 1
          private_endpoints = [
            { subnet = "snet-app-sp01-npd-uks-001" },
            { subnet = "snet-data-sp01-npd-uks-001" },
          ]
        },
      ]
    }
  }
  assert {
    condition = alltrue([
      contains(keys(output.names), "pepsp01npduks001001"),
      contains(keys(output.names), "pepsp01npduks001002"),
    ])
    error_message = "Expected two positional PEs under storage instance 001 (concatenated child of concatenated parent — FR-030)."
  }
}
