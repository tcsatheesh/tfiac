# T010 - cross-field invariants enforced via terraform_data preconditions so
# failures surface at plan time (FR-110). Messages name the offending value so
# operators can pinpoint the fix without re-reading the spec.

resource "terraform_data" "assertions" {
  triggers_replace = {
    workspace_name_hash = sha1(local.workspace_canonical_name)
    rg_name_hash        = sha1(local.rg_canonical_name)
  }

  lifecycle {
    # LOG-INV-9: the engine MUST have emitted a name entry for the workspace
    # at the canonical key we synthesised in locals.tf. If this fails the
    # engine catalogue or shape logic has drifted.
    precondition {
      condition     = contains(keys(module.naming.names), local.workspace_canonical_name)
      error_message = "LOG-INV-9: naming engine did not emit workspace key \"${local.workspace_canonical_name}\". Engine keys: ${jsonencode(sort(keys(module.naming.names)))}."
    }

    # LOG-INV-9 (RG twin): same check for the RG canonical name.
    precondition {
      condition     = contains(keys(module.naming.names), local.rg_canonical_name)
      error_message = "LOG-INV-9: naming engine did not emit RG key \"${local.rg_canonical_name}\". Engine keys: ${jsonencode(sort(keys(module.naming.names)))}."
    }
  }
}
