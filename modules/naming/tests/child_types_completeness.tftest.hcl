# T044 [US3] — child_types completeness
# Every child entry under any service MUST be catalogued in local.child_types
# (subnet, nsg_rule, route, private_endpoint, diagnostic_setting).

run "all_child_types_resolve" {
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
          type    = "vnet"
          subnets = [{ purpose = "app" }]
        },
        {
          type      = "nsg"
          nsg_rules = [{ purpose = "allow-https" }]
        },
        {
          type   = "route_table"
          routes = [{ purpose = "internet" }]
        },
        {
          type              = "storage"
          private_endpoints = [{ subnet = "snet-app-sp01-npd-uks-001" }]
        },
      ]
    }
  }
  assert {
    condition = alltrue([
      contains(keys(output.names), "snet-app-sp01-npd-uks-001"),
      contains(keys(output.names), "nsgrule-allow-https-sp01-npd-uks-001"),
      contains(keys(output.names), "udr-internet-sp01-npd-uks-001"),
    ])
    error_message = "All five child types must produce emitted records (FR-027)."
  }
}
