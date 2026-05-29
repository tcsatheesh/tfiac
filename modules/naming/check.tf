# Cross-field assertions for the naming engine.
# Each precondition maps 1:1 to an invariant in
# specs/001-naming-convention-engine/data-model.md.
# A failed precondition aborts `terraform plan` with the message
# below; callers never see a partially-built name map.

resource "terraform_data" "assertions" {
  input = "naming-engine assertions"

  lifecycle {
    precondition {
      condition     = length(local.services_unknown_types) == 0
      error_message = "INV-1: unknown service_type in var.services: ${jsonencode(local.services_unknown_types)}. Add a row to modules/naming/catalogue/services.tf (and to spec.md) or fix the entry."
    }

    precondition {
      condition     = length(local.children_unknown_types) == 0
      error_message = "INV-1: unknown service_type in var.children: ${jsonencode(local.children_unknown_types)}. Children must use a child-level row from the catalogue."
    }

    precondition {
      condition     = local.region_known
      error_message = "INV-10: unknown region short code \"${var.input.region}\". Known codes: ${jsonencode(sort(keys(module.catalogue.regions)))}. Add the region to modules/naming/catalogue/regions.tf if it is missing."
    }

    precondition {
      condition     = length(local.services_rg_shape_violations) == 0
      error_message = "INV-4: resource_group entries MUST NOT set service_purpose; all other (non-FQDN) entries MUST set it. Violating keys: ${jsonencode(local.services_rg_shape_violations)}."
    }

    precondition {
      condition     = length(local.duplicate_key_groups) == 0
      error_message = "INV-2: duplicate key within (service_type, service_purpose) group(s): ${jsonencode(local.duplicate_key_groups)}. Every services[*].key must be unique within its group."
    }

    precondition {
      condition     = length(local.oversize_groups) == 0
      error_message = "INV-3: per-group instance count exceeds 999: ${jsonencode(local.oversize_groups)}. Split the workload across additional service_purpose groups."
    }

    precondition {
      condition     = length(local.stack_extra_tags_collisions) == 0
      error_message = "INV-8: var.extra_tags collides with baseline keys: ${jsonencode(local.stack_extra_tags_collisions)}. Baseline keys are engine-owned and cannot be overridden."
    }

    precondition {
      condition     = length(local.entry_extra_tags_collisions) == 0
      error_message = "INV-8: per-entry services[*].extra_tags collide with baseline keys: ${jsonencode(local.entry_extra_tags_collisions)}."
    }

    precondition {
      condition     = length(local.child_extra_tags_collisions) == 0
      error_message = "INV-8: per-entry children[*].extra_tags collide with baseline keys: ${jsonencode(local.child_extra_tags_collisions)}."
    }

    precondition {
      condition     = length(local.children_unknown_parents) == 0
      error_message = "Child entry references an unknown parent_key: ${jsonencode(local.children_unknown_parents)}. parent_key must equal the `key` of a top-level entry."
    }

    precondition {
      condition     = length(local.children_parent_type_mismatches) == 0
      error_message = "Child/parent service_type mismatch (child catalogue's parent_type does not match parent's service_type): ${jsonencode(local.children_parent_type_mismatches)}."
    }

    precondition {
      condition     = length(local.children_purpose_violations) == 0
      error_message = "Child child_purpose violation: required for child_purpose-shaped children (subnet, nsg_rule, route, apim_api); forbidden for singleton (vnet_bastion, vnet_firewall) and positional (private_endpoint, diagnostic_setting). Violating entries: ${jsonencode(local.children_purpose_violations)}."
    }

    precondition {
      condition     = length(local.singleton_overflow) == 0
      error_message = "INV-5: singleton child has more than one entry per parent: ${jsonencode(local.singleton_overflow)}. vnet_bastion / vnet_firewall allow at most 1 per parent."
    }

    precondition {
      condition     = length(local.duplicate_child_key_groups) == 0
      error_message = "Duplicate child key within (child_type, parent_key) group(s): ${jsonencode(local.duplicate_child_key_groups)}."
    }
  }
}
