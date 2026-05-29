# Public outputs for modules/naming.
# See specs/001-naming-convention-engine/contracts/naming-engine.md
# for the authoritative contract; bump engine_version per the semver
# policy in that document.

output "engine_version" {
  description = "Semver of the naming engine. Pin against this in consumer stacks to detect contract-affecting upgrades."
  value       = "0.1.0"
}

output "names" {
  description = "Map keyed by canonical Azure resource name. Each value carries {service_type, service_purpose, stack_purpose, parent, tags, azure_max}."

  # depends_on on terraform_data.assertions ensures every precondition
  # fires before this output is rendered; if any assertion fails the
  # user sees that specific error, not a name-composition fallout.
  value = local.all_names

  depends_on = [terraform_data.assertions]

  # INV-6: each canonical name fits within its catalogue azure_max.
  precondition {
    condition = alltrue([
      for name, entry in local.all_names :
      length(name) <= entry.azure_max
    ])
    error_message = "INV-6: at least one canonical name exceeds its Azure max length. Offending entries: ${jsonencode([
      for name, entry in local.all_names :
      format("%s (%d > %d)", name, length(name), entry.azure_max)
      if length(name) > entry.azure_max
    ])}"
  }

  # INV-7: every canonical name is non-empty and matches the
  # union charset across all shapes (lowercase alphanumerics, hyphen,
  # and dot for FQDNs).
  precondition {
    condition = alltrue([
      for name, _ in local.all_names :
      can(regex("^[a-z0-9.-]+$", name)) && length(name) > 0
    ])
    error_message = "INV-7: at least one canonical name violates the shape charset (lowercase, digits, '-', '.'): ${jsonencode([
      for name, _ in local.all_names : name
      if !can(regex("^[a-z0-9.-]+$", name))
    ])}"
  }

  # INV-9: every emitted tag key <= 512 chars and value <= 256 chars.
  precondition {
    condition = alltrue(flatten([
      for _, entry in local.all_names : [
        for k, v in entry.tags :
        length(k) <= 512 && length(v) <= 256
      ]
    ]))
    error_message = "INV-9: at least one tag key/value exceeds Azure limits (key<=512, value<=256)."
  }
}
