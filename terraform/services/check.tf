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
      var.enable_aifoundry_private_endpoint == true &&
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
      var.enable_aifoundry_application_insights == true &&
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
      var.enable_container_registry_private_endpoint == true &&
      length([for s in var.services : s if s.type == "container_registry"]) == 0
    )
    error_message = "C-020 / FR-029 — enable_container_registry_private_endpoint = true requires a 'container_registry' selection in this services stack."
  }
}

# storage_pe_requires_storage (spec.md C-035 / FR-034): enabling the storage
# private endpoint only makes sense when a `storage` account is actually
# selected in this stack. Fires at plan time, before any remote-state or
# provider call. Defence-in-depth pair for the variable-level
# vnet/dns_state_backend requirement.
check "storage_pe_requires_storage" {
  assert {
    condition = !(
      var.enable_storage_private_endpoint == true &&
      length([for s in var.services : s if s.type == "storage"]) == 0
    )
    error_message = "C-035 / FR-034 — enable_storage_private_endpoint = true requires a 'storage' selection in this services stack."
  }
}

check "search_pe_requires_search" {
  assert {
    condition = !(
      var.enable_search_private_endpoint == true &&
      length([for s in var.services : s if s.type == "search"]) == 0
    )
    error_message = "C-039 / FR-035 — enable_search_private_endpoint = true requires a 'search' selection in this services stack."
  }
}

# C-050 / FR-041 — keyvault_pe_requires_keyvault: enabling the Key Vault private
# endpoint explicitly only makes sense when a `keyvault` is actually selected in
# this stack. Fires only on explicit opt-in (the master switch does not require
# a keyvault to exist). Defence-in-depth pair for the variable-level
# vnet/dns_state_backend requirement.
check "keyvault_pe_requires_keyvault" {
  assert {
    condition = !(
      var.enable_keyvault_private_endpoint == true &&
      length([for s in var.services : s if s.type == "keyvault"]) == 0
    )
    error_message = "C-050 / FR-041 — enable_keyvault_private_endpoint = true requires a 'keyvault' selection in this services stack."
  }
}

# C-049 / FR-041 — private_by_default_requires_backends: when the
# private-by-default master is on and ANY PE-capable service (aifoundry,
# container_registry, storage, search, keyvault) is selected, both remote-state
# backends MUST be supplied so the inherited private endpoints can resolve their
# spoke subnet + hub DNS zone. Friendly aggregate companion to the per-variable
# validations (which fire earlier, per service). Fires at plan time, before any
# remote-state read.
check "private_by_default_requires_backends" {
  assert {
    condition = !(
      var.private_by_default &&
      (local.aifoundry_selected || local.registry_selected || local.storage_selected || local.search_selected || local.keyvault_selected) &&
      (var.vnet_state_backend == null || var.dns_state_backend == null)
    )
    error_message = "C-049 / FR-041 — private_by_default = true with a PE-capable service (aifoundry / container_registry / storage / search / keyvault) selected requires BOTH vnet_state_backend (PE subnet) and dns_state_backend (private DNS zones). Supply both backends, or set private_by_default = false (and opt into specific private endpoints individually)."
  }
}

# C-053 / FR-042 — aifoundry_private_requires_private_deps: a PRIVATE Foundry
# account (local.aifoundry_pe_required, i.e. an aifoundry selected with its PE
# resolved on via the FR-041 master/toggle) must not sit beside a
# selected-but-PUBLIC supporting service. Every SELECTED storage / search /
# keyvault must have its resolved PE toggle true. cosmosdb is always private
# (FR-032) and the Foundry App Insights is master-driven (FR-028), so neither
# needs a check. Guard only — never auto-provisions an unselected service
# (Principle II / C-053). Lists each public offender.
check "aifoundry_private_requires_private_deps" {
  assert {
    condition = !local.aifoundry_pe_required || length(concat(
      local.storage_selected && !local.storage_pe_required ? ["storage"] : [],
      local.search_selected && !local.search_pe_required ? ["search"] : [],
      local.keyvault_selected && !local.keyvault_pe_required ? ["keyvault"] : [],
    )) == 0
    error_message = format(
      "C-053 / FR-042 — a private AI Foundry account requires its SELECTED supporting services to be private too, but the following are public: %s. Enable their private endpoints (remove the explicit enable_<svc>_private_endpoint = false, or set it true), or remove them from this stack. Cosmos DB is always private (FR-032).",
      jsonencode(concat(
        local.storage_selected && !local.storage_pe_required ? ["storage"] : [],
        local.search_selected && !local.search_pe_required ? ["search"] : [],
        local.keyvault_selected && !local.keyvault_pe_required ? ["keyvault"] : [],
      )),
    )
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

# cosmosdb_requires_backends (spec.md FR-032): Cosmos DB is private-only, so
# selecting a 'cosmosdb' service requires both the spoke VNet remote state (PE
# subnet) and the hub DNS remote state (cosmos-sql zone). Fires at plan time,
# before any remote-state or provider call. Defence-in-depth pair for the
# variable-level vnet/dns_state_backend requirement.
check "cosmosdb_requires_backends" {
  assert {
    condition = !(
      length([for s in var.services : s if s.type == "cosmosdb"]) > 0 &&
      (var.vnet_state_backend == null || var.dns_state_backend == null)
    )
    error_message = "FR-032 — selecting a 'cosmosdb' service requires both vnet_state_backend (PE subnet) and dns_state_backend (cosmos-sql zone) to be set; Cosmos DB is private-only."
  }
}

# aifoundry_network_injection_prereqs (spec.md FR-033 / C-031..C-033, amended
# FR-044 / C-060): when Hosted-Agent network injection is enabled, the
# capability host needs exactly one each of aifoundry / cosmosdb / search plus
# the BYO agent storage AND a private account. The storage count is normally
# exactly one, but when userOwnedStorage is also enabled (FR-044) the account
# additionally owns a 2nd storage, so exactly TWO storages are expected.
check "aifoundry_network_injection_prereqs" {
  assert {
    condition = !var.enable_aifoundry_network_injection || (
      coalesce(var.enable_aifoundry_private_endpoint, var.private_by_default) &&
      length([for s in var.services : s if s.type == "aifoundry"]) == 1 &&
      length([for s in var.services : s if s.type == "storage"]) == (var.enable_aifoundry_user_owned_storage ? 2 : 1) &&
      length([for s in var.services : s if s.type == "cosmosdb"]) == 1 &&
      length([for s in var.services : s if s.type == "search"]) == 1
    )
    error_message = "FR-033 — enable_aifoundry_network_injection = true requires enable_aifoundry_private_endpoint = true and EXACTLY ONE each of 'aifoundry', 'cosmosdb', and 'search', plus the BYO 'storage' leg (one 'storage', or TWO when enable_aifoundry_user_owned_storage = true so the account also owns a 2nd userOwnedStorage)."
  }
}

# aifoundry_user_owned_storage_prereqs (spec.md FR-044 / C-060): when
# userOwnedStorage is enabled the stack must hold an aifoundry account plus
# EXACTLY TWO 'storage' selections, and both disambiguating purposes must be set
# and distinct so local.agent_byo_storage_id / local.account_owned_storage_id
# each resolve to exactly one storage. Defence-in-depth pair for the
# variable-level validators + the one(...) resolvers in locals.tf.
check "aifoundry_user_owned_storage_prereqs" {
  assert {
    condition = !var.enable_aifoundry_user_owned_storage || (
      length([for s in var.services : s if s.type == "aifoundry"]) == 1 &&
      length([for s in var.services : s if s.type == "storage"]) == 2 &&
      var.agent_storage_purpose != null &&
      var.account_storage_purpose != null &&
      var.agent_storage_purpose != var.account_storage_purpose
    )
    error_message = "FR-044 — enable_aifoundry_user_owned_storage = true requires EXACTLY ONE 'aifoundry' and EXACTLY TWO 'storage' selections, with both agent_storage_purpose and account_storage_purpose set to distinct values (so the BYO agent store and the account's userOwnedStorage are distinguishable)."
  }
}

# aifoundry_keyvault_connection_prereqs (spec.md FR-045 / C-061): when the
# Key Vault connection is enabled the stack must hold an aifoundry account plus
# EXACTLY ONE 'keyvault' selection (the connection target), so the
# one(...) keyvault resolver in main.tf yields a single id.
check "aifoundry_keyvault_connection_prereqs" {
  assert {
    condition = !var.enable_aifoundry_keyvault_connection || (
      length([for s in var.services : s if s.type == "aifoundry"]) == 1 &&
      length([for s in var.services : s if s.type == "keyvault"]) == 1
    )
    error_message = "FR-045 — enable_aifoundry_keyvault_connection = true requires EXACTLY ONE 'aifoundry' and EXACTLY ONE 'keyvault' selected (the account's AzureKeyVault connection target)."
  }
}

# private_by_default_unwired_types (spec.md FR-041 §4 / C-053): the master
# private-by-default switch only flips the public-access + private-endpoint
# surface for the service types that are already wired for it (aifoundry,
# container_registry, storage, search, keyvault + the telemetry exception of
# app_insights / log_analytics / Foundry-tracing). For every OTHER selectable
# type that has its own private-link surface but is not yet wired to the
# master, emit a plan-time WARNING (check blocks are non-blocking) so operators
# know the master currently has NO effect on it and PE wiring is a tracked
# follow-up. This intentionally never blocks a plan.
check "private_by_default_unwired_types" {
  assert {
    condition = !(
      var.private_by_default &&
      length([
        for s in var.services : s
        if contains(
          ["openai", "language", "doc_intel", "apim", "function_app", "logic_app", "aml_workspace"],
          s.type
        )
      ]) > 0
    )
    error_message = "FR-041 §4 — private_by_default = true is selected together with one or more service types whose private-endpoint wiring is a tracked follow-up (any of: openai, language, doc_intel, apim, function_app, logic_app, aml_workspace). The master switch currently has NO public-access / private-endpoint effect on those types; deploy them with their own explicit network controls until the follow-up lands. (This is a WARNING; the plan is not blocked.)"
  }
}
