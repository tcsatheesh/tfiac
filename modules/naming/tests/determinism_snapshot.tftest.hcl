# T019 [US1] — determinism_snapshot (FR-006 / FR-038)
# Reference input from quickstart.md. Asserts byte-identical output.names
# against the committed snapshot.

run "snapshot_matches" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "tcsatheesh/tfiac"
      services = [
        {
          type = "vnet"
          subnets = [
            { purpose = "app" },
            { purpose = "data" },
          ]
        },
        { type = "storage", count = 2 },
        { type = "keyvault" },
      ]
      overrides = {
        "stsp01npduks001" = { account_tier = "Premium" }
      }
    }
  }
  assert {
    condition     = jsonencode(output.names) == file("${path.module}/tests/snapshots/reference.json")
    error_message = "module.naming.names diverges from committed reference snapshot. If the change is intentional, regenerate tests/snapshots/reference.json in the same PR and document the cause."
  }
}
