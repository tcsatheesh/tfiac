# Plan-time hard-fails (data-model § 1; CA-003, CA-006).
# Stack-owned checks (the engine has no topology/inventory/overrides concept).

check "subscription_match" {
  assert {
    condition = data.azurerm_client_config.current.subscription_id == var.subscription_id
    error_message = format(
      "subscription_match: provider-bound subscription (%s) does not match var.subscription_id (%s). Inject the correct value at runtime per CA-011.",
      data.azurerm_client_config.current.subscription_id,
      var.subscription_id,
    )
  }
}

# v1_selectable_inventory: the variable-level validation in variables.tf
# already rejects non-allowlisted types at plan time. This check block adds
# a friendlier per-offender message that names the owning stack or the
# "deferred" reason from local.deferred_reason. It fires when an operator
# adds a type that IS in the engine catalogue but NOT in v1_selectable_types
# (e.g. "vnet", "dns_zone", "firewall").
check "v1_selectable_inventory" {
  assert {
    condition = length([
      for s in var.services : s.type
      if !contains(local.v1_selectable_types, s.type)
    ]) == 0
    error_message = format(
      "v1_selectable_inventory: the following services[*].type values are not v1-selectable: %s.",
      jsonencode([
        for s in var.services :
        format(
          "%s (%s)",
          s.type,
          lookup(local.deferred_reason, s.type, "unknown service type — see spec.md C-001.")
        )
        if !contains(local.v1_selectable_types, s.type)
      ])
    )
  }
}

# overrides_keys_resolved: every key in var.overrides MUST equal an
# engine-emitted canonical name (CA-006).
check "overrides_keys_resolved" {
  assert {
    condition = length([
      for k in keys(var.overrides) : k
      if !contains(keys(module.naming.names), k)
    ]) == 0
    error_message = format(
      "overrides_keys_resolved: the following override keys do not match any engine-emitted canonical name: %s. Valid keys: %s.",
      jsonencode([for k in keys(var.overrides) : k if !contains(keys(module.naming.names), k)]),
      jsonencode(sort(keys(module.naming.names))),
    )
  }
}

# apim_hub_only (spec.md C-013): apim is hub-only. Selecting it from a stack
# with topology != "hub" is rejected at plan time, BEFORE any provider call.
# This is the stack-level half of the defence-in-depth pairing; the wrapper
# (modules/apim/check.tf) carries the matching precondition for any
# out-of-tree caller. The lifecycle.precondition on azurerm_resource_group.svc
# (terraform/services/main.tf) is the third layer — kept for symmetry with the
# always-present RG resource so the failure fires even if `check` blocks are
# downgraded to warnings by a future Terraform release. See spec.md C-013.
check "apim_hub_only" {
  assert {
    condition = !(var.topology != "hub" && length([
      for s in var.services : s if s.type == "apim"
    ]) > 0)
    error_message = format(
      "C-013 — apim is hub-only: topology=%q with apim in services[*] is not supported. Move the apim entry into variables/hub/<env>/services.tfvars.json or drop it from this spoke. See spec.md C-013.",
      var.topology,
    )
  }
}
