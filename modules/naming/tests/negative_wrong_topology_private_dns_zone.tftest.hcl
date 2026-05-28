# T036 [US4] — negative_wrong_topology_private_dns_zone (FR-033)
#
# private_dns_zone has topology_scope=prd-hub-only. A spoke/npd request
# must hard-fail the engine's check.topology_scope.

run "private_dns_zone_in_spoke_npd_fails" {
  command = plan

  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "swedencentral"
      repo        = "tcsatheesh/tfiac"
      services = [
        {
          type  = "private_dns_zone"
          count = 1
        },
      ]
    }
  }

  expect_failures = [
    check.topology_scope,
  ]
}
