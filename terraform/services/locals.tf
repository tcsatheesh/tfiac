# Stack-level derivations.
# Hardcodes stack_purpose = "svc" (mirrors terraform/vnet/locals.tf::naming_input.stack_purpose = "net").
# Flattens var.services into engine entries per data-model § 3 / R-2.

locals {
  # ----- Engine input bundle -----
  naming_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = var.usecase
    stack_purpose = "svc"
    repo          = var.repo
  }

  # ----- v1 selectable type allowlist (spec.md C-001 + C-015) -----
  v1_selectable_types = [
    "keyvault", "storage", "log_analytics", "app_insights", "container_registry",
    "user_assigned_identity", "search", "openai", "aifoundry", "aifoundry_project",
    "language", "doc_intel", "function_app", "logic_app", "aml_workspace", "apim",
    "container_app_environment", "cosmosdb",
  ]

  # ----- Deferred / other-stack-owned reasons (CA-003 friendly messages) -----
  # Other engine catalogue rows that someone might mistakenly add to var.services.
  # The variable-level validation in variables.tf already rejects them; this map
  # backs the friendlier check "v1_selectable_inventory" assert below.
  deferred_reason = {
    vnet                 = "owned by terraform/vnet/ — provision there, not in services."
    nsg                  = "owned by terraform/vnet/ (per-subnet)."
    route_table          = "owned by terraform/vnet/."
    public_ip            = "owned by terraform/vnet/ (firewall/bastion only)."
    vm                   = "deferred to follow-up; see spec.md A4."
    app_service_plan     = "deferred to follow-up; bundled with function_app wrapper."
    vpn_gateway          = "deferred to follow-up; see spec.md A4."
    expressroute_gateway = "deferred to follow-up; see spec.md A4."
    dns_zone             = "owned by terraform/dns/."
    private_dns_zone     = "owned by terraform/dns/."
    firewall             = "owned by terraform/vnet/ (hub firewall only)."
  }

  # ----- Per-type 3-letter slug for synthetic engine key (R-2 step 3) -----
  type_short = {
    keyvault                  = "kvl"
    storage                   = "sto"
    log_analytics             = "log"
    app_insights              = "api"
    container_registry        = "cnt"
    user_assigned_identity    = "uai"
    search                    = "srh"
    openai                    = "oai"
    aifoundry                 = "aif"
    aifoundry_project         = "aifp"
    language                  = "lan"
    doc_intel                 = "dci"
    function_app              = "fna"
    logic_app                 = "lga"
    aml_workspace             = "aml"
    apim                      = "apm"
    container_app_environment = "cae"
    cosmosdb                  = "cos"
  }

  # ----- Step A: group var.services by (type, coalesce(purpose, usecase)) -----
  _entries_by_group = {
    for s in var.services :
    format("%s|%s", s.type, coalesce(s.purpose, var.usecase)) => s...
  }

  # ----- Step B: sort entries within each group by stable JSON serialisation -----
  _sorted_entries_by_group = {
    for gk, entries in local._entries_by_group :
    gk => [for s_json in sort([for s in entries : jsonencode(s)]) : jsondecode(s_json)]
  }

  # ----- Step C: assemble engine records (synthetic 9-char key per data-model § 3) -----
  engine_services = concat(
    [{
      service_type    = "resource_group"
      service_purpose = null
      stack_purpose   = "svc"
      key             = "rg001"
      fqdn            = null
      extra_tags      = {}
    }],
    flatten([
      for gk in sort(keys(local._sorted_entries_by_group)) : flatten([
        for entry_idx, s in local._sorted_entries_by_group[gk] : [
          for n in range(1, s.count + 1) : {
            service_type    = s.type
            service_purpose = coalesce(s.purpose, var.usecase)
            stack_purpose   = null
            key             = format("%s%03d%03d", local.type_short[s.type], entry_idx + 1, n)
            fqdn            = null
            extra_tags      = {}
          }
        ] if s.count > 0
      ])
    ]),
  )
}

# FR-041 / FR-042 (Amendment 2026-06-03) — per-type selection helpers. Used by
# the private-by-default resolution (data.vnetdns.tf) to gate each PE toggle on
# the relevant service actually being selected, and by the Foundry
# private-endpoint dependency guard (check.tf) to enumerate selected supporting
# services. Mirrors the existing local.cosmosdb_selected (data.vnetdns.tf).
locals {
  aifoundry_selected = length([for s in var.services : s if s.type == "aifoundry"]) > 0
  registry_selected  = length([for s in var.services : s if s.type == "container_registry"]) > 0
  storage_selected   = length([for s in var.services : s if s.type == "storage"]) > 0
  search_selected    = length([for s in var.services : s if s.type == "search"]) > 0
  keyvault_selected  = length([for s in var.services : s if s.type == "keyvault"]) > 0
}
