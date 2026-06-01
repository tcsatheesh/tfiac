# Root-stack composition.
# - Engine invocation (module.naming) gives us the canonical-name map.
# - One azurerm_resource_group "svc" + N wrapper-module invocations per v1
#   selectable type, keyed by canonical name.

data "azurerm_client_config" "current" {}

module "naming" {
  source = "../../modules/naming"

  input    = local.naming_input
  services = local.engine_services
}

# Resolve the single svc RG canonical name from the engine output.
locals {
  svc_rg_name     = one([for k, v in module.naming.names : k if v.service_type == "resource_group"])
  svc_rg_location = module.naming.names[local.svc_rg_name].tags.region
  svc_rg_tags     = module.naming.names[local.svc_rg_name].tags
}

resource "azurerm_resource_group" "svc" {
  name     = local.svc_rg_name
  location = local.svc_rg_location
  tags     = local.svc_rg_tags

  lifecycle {
    # C-013 (Amendment 2026-05-31) — apim is hub-only.
    # Hard-fail at plan time, BEFORE any provider call, when a spoke
    # invocation tries to select apim. The wrapper carries a defence-in-depth
    # precondition (modules/apim/check.tf) for any out-of-tree caller.
    precondition {
      condition = !(var.topology != "hub" && length([
        for s in var.services : s if s.type == "apim"
      ]) > 0)
      error_message = format(
        "C-013 — apim is hub-only: topology=%q with apim in services[*] is not supported. Either move the apim selection into variables/hub/<env>/services.tfvars.json or drop it from this spoke. See spec.md C-013.",
        var.topology,
      )
    }
    # C-017 / FR-026 — aifoundry_project requires exactly one aifoundry
    # (Cognitive Services Foundry account) selection in the same services
    # stack so the project wrapper can resolve parent_id. Defence-in-depth
    # pair for `check "aifoundry_project_requires_account"` in check.tf —
    # the precondition fires BEFORE module-variable validation so an
    # operator gets a meaningful error instead of "var.parent_account_id
    # is null".
    precondition {
      condition = !(
        length([for s in var.services : s if s.type == "aifoundry_project"]) > 0 &&
        length([for s in var.services : s if s.type == "aifoundry"]) != 1
      )
      error_message = "C-017 / FR-026 — aifoundry_project requires exactly one 'aifoundry' (Cognitive Services account) selection in the same services stack. Add an 'aifoundry' entry to services[*] alongside the 'aifoundry_project' entry, or remove the project."
    }
  }
}

# ----- Per-type wrapper invocations (one block per v1 selectable type) -----
# Each block keys on the canonical name. Filter `module.naming.names` by
# `service_type == "<type>"`. Wrappers receive the canonical name + RG +
# location + tags + the full engine record + per-instance overrides.

module "keyvault" {
  source = "../../modules/keyvault"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "keyvault"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "storage" {
  source = "../../modules/storage"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "storage"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

# log_analytics: special-cased to consume the pre-existing modules/loganalytics/
# wrapper (feature 003 interface — keeps terraform/log/ untouched per CLAUDE.md
# "preserve existing behaviour"). The wrapper instantiates its own naming
# engine + RG with stack_purpose="log"; the services stack does NOT add it to
# the svc RG. Operators who deploy log_analytics in services MUST pick a
# (tenant, env) where terraform/log/ is not already deployed (default day-one
# config keeps the log stack on `(hub, npd|prd, swc)`, services on `(*, *, uks)`
# — no collision).
module "log_analytics" {
  source = "../../modules/loganalytics"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "log_analytics"
  }

  input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = var.usecase
    stack_purpose = "log"
    repo          = var.repo
  }
  # workspace_key is the engine-internal key; pass through a deterministic
  # value derived from the canonical name so two reorder-equivalent inputs
  # produce identical wrapper invocations.
  workspace_key = "central"
}
# C-014 (Amendment 2026-05-31) — log_analytics wrapper is EXEMPT from
# shared-LA diagnostic wiring: the wrapper IS the sink (a workspace cannot
# diagnose itself), and its public interface predates the C-014 amendment.
# See spec.md C-014 § (3).

module "app_insights" {
  source = "../../modules/appinsights"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "app_insights"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "container_registry" {
  source = "../../modules/cntreg"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "container_registry"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "user_assigned_identity" {
  source = "../../modules/uai"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "user_assigned_identity"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "search" {
  source = "../../modules/search"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "search"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "openai" {
  source = "../../modules/openai"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "openai"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "aifoundry" {
  source = "../../modules/aifoundry"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "aifoundry"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
  # C-017 (Amendment 2026-05-30) — the Cognitive Services Foundry account
  # manages its own storage/secrets; sibling KV/SA wiring removed.

  # C-018 (Amendment 2026-05-31) — opt-in account private endpoint (FR-027).
  # All three inputs resolve to inert defaults (false / null / []) unless
  # enable_aifoundry_private_endpoint is set, preserving day-one behaviour.
  private_endpoint_enabled   = var.enable_aifoundry_private_endpoint
  private_endpoint_subnet_id = local.pe_subnet_id
  private_dns_zone_ids       = local.pe_zone_ids

  # C-019 (Amendment 2026-06-01) — opt-in App Insights tracing (FR-028). The
  # hub LA id is already supplied via shared_log_analytics_workspace_id above;
  # default false preserves day-one behaviour.
  application_insights_enabled = var.enable_aifoundry_application_insights
}

module "aifoundry_project" {
  source = "../../modules/aifoundryproject"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "aifoundry_project"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
  # C-017 (Amendment 2026-05-30) — Project parented directly by the Foundry
  # account (Microsoft.CognitiveServices/accounts). v1 enforces exactly one
  # aifoundry account per stack when aifoundry_project is selected
  # (root-stack precondition aifoundry_project_requires_account in check.tf).
  # Tags are inherited from the parent account; `location` is re-declared
  # on the child only because the RP returns 400 LocationRequired without it
  # (confirmed live 2026-05-30).
  parent_account_id = one([for k, v in module.aifoundry : v.resource_id])
}

module "language" {
  source = "../../modules/language"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "language"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "doc_intel" {
  source = "../../modules/docint"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "doc_intel"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "function_app" {
  source = "../../modules/fnapp"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "function_app"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "logic_app" {
  source = "../../modules/lgapp"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "logic_app"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "aml_workspace" {
  source = "../../modules/aml"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "aml_workspace"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
}

module "apim" {
  source = "../../modules/apim"
  # C-013 (Amendment 2026-05-31) — gate apim wrapper instantiation by
  # topology so a spoke invocation never reaches the wrapper. The root
  # check.apim_hub_only + RG precondition still report the C-013 error
  # to the operator; this gate ensures only one diagnostic surfaces
  # (test-friendly + cleaner UX). The wrapper's own precondition stays
  # as defence-in-depth for any out-of-tree caller.
  for_each = var.topology != "hub" ? {} : {
    for n, e in module.naming.names : n => e if e.service_type == "apim"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id
  # C-013 (Amendment 2026-05-31) — apim hub-only defence-in-depth.
  topology = var.topology
}
