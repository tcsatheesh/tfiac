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

  # C-050 (Amendment 2026-06-03) — private endpoint (FR-041). Resolved from the
  # private-by-default master (local.keyvault_pe_required): when on, the vault
  # gets public network access disabled (network_acls Deny / AzureServices
  # bypass) and a PE (subresource 'vault') into the spoke VNet + the hub
  # privatelink.vaultcore.azure.net zone. Inert defaults (false / null / [])
  # when off.
  private_endpoint_enabled   = local.keyvault_pe_required
  private_endpoint_subnet_id = local.keyvault_pe_subnet_id
  private_dns_zone_ids       = local.keyvault_pe_zone_ids
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

  # C-035 (Amendment 2026-06-02) — private endpoint (FR-034). Resolved from the
  # private-by-default master (local.storage_pe_required, FR-041): inert
  # defaults (false / null / []) only when public is explicitly chosen.
  # Required so a Foundry Hosted-Agent BYO thread/file store stays private
  # (FR-033).
  private_endpoint_enabled   = local.storage_pe_required
  private_endpoint_subnet_id = local.storage_pe_subnet_id
  private_dns_zone_ids       = local.storage_pe_zone_ids
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

  # C-051 (Amendment 2026-06-03) — public-access surface (FR-041 §2). Under
  # private-by-default the selectable Log Analytics workspace disables internet
  # ingestion/query (no classic PE; AMPLS is the tracked follow-up).
  internet_access_enabled = !var.private_by_default
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

  # C-051 (Amendment 2026-06-03) — public-access surface (FR-041 §2). Under
  # private-by-default the selectable App Insights disables internet
  # ingestion/query (no classic PE; AMPLS is the tracked follow-up).
  internet_access_enabled = !var.private_by_default
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

  # C-020 (Amendment 2026-06-01) — private endpoint (FR-029). Resolved from the
  # private-by-default master (local.acr_pe_required, FR-041): when on the
  # registry is Premium with public access disabled + a PE; inert defaults
  # (false / null / []) only when public is explicitly chosen.
  private_endpoint_enabled   = local.acr_pe_required
  private_endpoint_subnet_id = local.acr_pe_subnet_id
  private_dns_zone_ids       = local.acr_pe_zone_ids
}

# C-021 (Amendment 2026-06-01) — internal (private) Container Apps environment
# (FR-030). Reachable only from the spoke VNet; the delegated subnet + spoke
# VNet id come from the vnet remote state (null when enable_container_apps is
# false, but the type is then unselectable via check.container_app_env_requires_subnet).
module "container_app_environment" {
  source = "../../modules/containerapps"
  # Only instantiate when the operator has explicitly enabled Container Apps and
  # wired the spoke VNet remote state. When the type is selected without
  # enable_container_apps, check.container_app_env_requires_subnet reports the
  # misconfiguration instead of a deep module validation error.
  for_each = {
    for n, e in module.naming.names : n => e
    if e.service_type == "container_app_environment" && var.enable_container_apps
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id

  infrastructure_subnet_id = local.container_apps_subnet_id
  vnet_id                  = local.spoke_vnet_id
}

# FR-032 (Amendment 2026-06-02) — private-by-default Azure Cosmos DB account
# (SQL/NoSQL API). Reachable only from the spoke VNet via an always-on private
# endpoint into the hub privatelink.documents.azure.com zone. The PE subnet (by
# role) + cosmos-sql zone id come from the vnet/dns remote state, which is
# required whenever a cosmosdb is selected (local.cosmosdb_selected). Usable as
# a standalone service or as the BYO thread store for a Foundry Hosted-Agent
# capability host.
module "cosmosdb" {
  source = "../../modules/cosmosdb"
  for_each = {
    for n, e in module.naming.names : n => e if e.service_type == "cosmosdb"
  }

  canonical_name      = each.key
  resource_group_name = azurerm_resource_group.svc.name
  location            = azurerm_resource_group.svc.location
  tags                = each.value.tags
  engine_record       = each.value
  overrides           = lookup(var.overrides, each.key, {})
  # C-014 (Amendment 2026-05-31) — shared hub LA wiring.
  shared_log_analytics_workspace_id = local.shared_la_workspace_id

  # FR-032 — private-only: always-on PE into the spoke PE subnet + cosmos-sql zone.
  private_endpoint_subnet_id = local.cosmosdb_pe_subnet_id
  private_dns_zone_ids       = local.cosmosdb_pe_zone_ids
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

  # C-039 (Amendment 2026-06-02) — private endpoint (FR-035). Resolved from the
  # private-by-default master (local.search_pe_required, FR-041): inert
  # defaults (false / null / []) only when public is explicitly chosen.
  # Required so a Foundry Hosted-Agent BYO vector store stays private (FR-033).
  private_endpoint_enabled   = local.search_pe_required
  private_endpoint_subnet_id = local.search_pe_subnet_id
  private_dns_zone_ids       = local.search_pe_zone_ids
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

  # C-018 (Amendment 2026-05-31) — account private endpoint (FR-027). Resolved
  # from the private-by-default master (local.aifoundry_pe_required, FR-041):
  # inert defaults (false / null / []) only when public is explicitly chosen.
  private_endpoint_enabled   = local.aifoundry_pe_required
  private_endpoint_subnet_id = local.pe_subnet_id
  private_dns_zone_ids       = local.pe_zone_ids

  # C-019 (Amendment 2026-06-01) — App Insights tracing (FR-028). Resolved from
  # the private-by-default master (local.appinsights_enabled, FR-041). The hub
  # LA id is already supplied via shared_log_analytics_workspace_id above.
  application_insights_enabled = local.appinsights_enabled

  # C-051 (Amendment 2026-06-03) — telemetry public-access surface (FR-041 §2).
  # Under private-by-default the Foundry-tracing App Insights disables internet
  # ingestion/query (no classic PE; AMPLS is the tracked follow-up).
  telemetry_internet_access_enabled = !var.private_by_default

  # C-031 (Amendment 2026-06-02) — opt-in Hosted-Agent network injection
  # (FR-033). Default false leaves all four inputs inert (false / null), so the
  # account body is identical to the post-FR-028 form. When enabled, bind the
  # account to the spoke agent subnet and thread the single selected BYO
  # Storage/Cosmos/Search instances; one(...) enforces exactly-one (C-033) and
  # is only evaluated when injection is on.
  network_injection_enabled = var.enable_aifoundry_network_injection
  agent_subnet_id           = local.agent_subnet_id
  agent_storage_account_id  = var.enable_aifoundry_network_injection ? one([for k, v in module.storage : v.resource_id]) : null
  agent_cosmosdb_account_id = var.enable_aifoundry_network_injection ? one([for k, v in module.cosmosdb : v.resource_id]) : null
  agent_search_service_id   = var.enable_aifoundry_network_injection ? one([for k, v in module.search : v.resource_id]) : null
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
