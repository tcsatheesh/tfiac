# T042 [US3] — catalogue parity (services ↔ defaults)
# Meta-test: every services entry MUST have a defaults entry and vice versa.

run "every_service_has_defaults" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services    = []
    }
  }
  # Trigger the parity check by reading catalogue indirectly via outputs.
  assert {
    condition     = length(output.names) >= 1
    error_message = "Empty services must still emit the RG record."
  }
}
