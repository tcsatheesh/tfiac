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

# aifoundry_project_requires_account (spec.md C-017 / FR-026; renamed by C-017
# from the C-015 §4 check `aifoundry_project_requires_hub`): selecting
# `aifoundry_project` requires exactly one `aifoundry` (Cognitive Services
# Foundry account) in the SAME services stack so the Project wrapper can wire
# `parent_id = var.parent_account_id`. C-017 also removes the former
# `aifoundry_requires_hub_deps` check — Foundry accounts manage their own
# storage/secrets and no longer need sibling KV/SA.
check "aifoundry_project_requires_account" {
  assert {
    condition = !(
      length([for s in var.services : s if s.type == "aifoundry_project"]) > 0 &&
      length([for s in var.services : s if s.type == "aifoundry"]) != 1
    )
    error_message = "C-017 / FR-026 — aifoundry_project requires exactly one 'aifoundry' (Cognitive Services account) selection in the same services stack."
  }
}

# environment_workload_only (spec.md C-016 / FR-025): the services stack is
# workload-only — `npd` is reserved for shared/hub stacks (terraform/log/,
# terraform/vnet/, terraform/dns/). This is the defence-in-depth pair for
# the variable validation on var.environment in variables.tf.
check "environment_workload_only" {
  assert {
    condition     = contains(["dev", "pre", "prd"], var.environment)
    error_message = "C-016 / FR-025 — environment must be one of dev|pre|prd for the services stack; 'npd' is reserved for shared/hub stacks."
  }
}

# aifoundry_pe_requires_account (spec.md C-018 / FR-027): enabling the Foundry
# account private endpoint only makes sense when an `aifoundry` account is
# actually selected in this stack. Fires at plan time, before any remote-state
# or provider call, with a clear remediation message. Defence-in-depth pair for
# the variable-level vnet/dns_state_backend requirement.
check "aifoundry_pe_requires_account" {
  assert {
    condition = !(
      var.enable_aifoundry_private_endpoint &&
      length([for s in var.services : s if s.type == "aifoundry"]) == 0
    )
    error_message = "C-018 / FR-027 — enable_aifoundry_private_endpoint = true requires an 'aifoundry' (Cognitive Services account) selection in this services stack."
  }
}

# aifoundry_appinsights_requires_account (spec.md C-019 / FR-028): enabling the
# Foundry App Insights tracing connection only makes sense when an `aifoundry`
# account is actually selected in this stack. Fires at plan time, before any
# provider call, with a clear remediation message. Defence-in-depth pair for
# the wrapper's always-required shared_log_analytics_workspace_id validator.
check "aifoundry_appinsights_requires_account" {
  assert {
    condition = !(
      var.enable_aifoundry_application_insights &&
      length([for s in var.services : s if s.type == "aifoundry"]) == 0
    )
    error_message = "C-019 / FR-028 — enable_aifoundry_application_insights = true requires an 'aifoundry' (Cognitive Services account) selection in this services stack."
  }
}

# acr_pe_requires_registry (spec.md C-020 / FR-029): enabling the ACR private
# endpoint only makes sense when a `container_registry` is actually selected in
# this stack. Fires at plan time, before any remote-state or provider call.
# Defence-in-depth pair for the variable-level vnet/dns_state_backend requirement.
check "acr_pe_requires_registry" {
  assert {
    condition = !(
      var.enable_container_registry_private_endpoint &&
      length([for s in var.services : s if s.type == "container_registry"]) == 0
    )
    error_message = "C-020 / FR-029 — enable_container_registry_private_endpoint = true requires a 'container_registry' selection in this services stack."
  }
}

# container_app_env_requires_subnet (spec.md C-021 / FR-030): selecting a
# `container_app_environment` requires enable_container_apps = true so the
# internal environment receives its delegated subnet + spoke VNet wiring from
# the vnet remote state. Fires at plan time. Defence-in-depth pair for the
# module's always-required infrastructure_subnet_id / vnet_id validators.
check "container_app_env_requires_subnet" {
  assert {
    condition = !(
      length([for s in var.services : s if s.type == "container_app_environment"]) > 0 &&
      !var.enable_container_apps
    )
    error_message = "C-021 / FR-030 — selecting a 'container_app_environment' requires enable_container_apps = true (which supplies the delegated subnet + spoke VNet wiring via vnet_state_backend)."
  }
}
