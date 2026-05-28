###############################################################################
# Naming Convention Engine
#
# Provider-less Terraform module that converts a single batch request into a
# flat map of canonical Azure resource names, baseline tags, default settings,
# and merged overrides.
#
# Source of truth:
#   - Spec:       specs/001-naming-convention-engine/spec.md
#   - Input:      specs/001-naming-convention-engine/contracts/input-schema.md
#   - Output:     specs/001-naming-convention-engine/contracts/output-schema.md
#   - Data model: specs/001-naming-convention-engine/data-model.md
#
# File layout:
#   versions.tf  -- required_version, empty required_providers
#   variables.tf -- variable "input" + validation blocks
#   catalogue.tf -- local.services, local.child_types, local.region_codes,
#                   local.defaults
#   locals.tf    -- staged transformations (stages 1..7)
#   validate.tf  -- module-level check {} blocks (hard plan-time errors)
#   outputs.tf   -- output "names" + output "by_type"
###############################################################################
