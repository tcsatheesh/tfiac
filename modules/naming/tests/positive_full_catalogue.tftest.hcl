# T018 [US1] — positive_full_catalogue
# Exercise every catalogued top-level service_type at least once,
# stratified by topology_scope (FR-023).
# Also assert FR-021: requested service_type round-trips with no prefix collapse.

run "either_types_in_spoke_npd" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        { type = "vnet" },
        { type = "nsg" },
        { type = "route_table" },
        { type = "public_ip" },
        { type = "log_analytics" },
        { type = "app_insights" },
        { type = "storage" },
        { type = "keyvault" },
        { type = "container_registry" },
        { type = "user_assigned_identity" },
        { type = "vm" },
        { type = "app_service_plan" },
        { type = "apim" },
      ]
    }
  }
  # FR-021 — no prefix collapse: each emitted record's service_type must equal
  # the requested value verbatim. (Defends against e.g. vnet vs vpn_gateway.)
  assert {
    condition = alltrue([
      for t in ["vnet", "nsg", "route_table", "public_ip", "log_analytics", "app_insights", "storage", "keyvault", "container_registry", "user_assigned_identity", "vm", "app_service_plan", "apim"] :
      length([for n, r in output.names : n if r.service_type == t]) == 1
    ])
    error_message = "Either-scoped service_type missing or duplicated (possible prefix collapse — FR-021)."
  }
}

run "hub_only_types_in_hub_prd" {
  command = plan
  variables {
    input = {
      topology    = "hub"
      tenant      = "hub"
      environment = "prd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        { type = "firewall" },
        { type = "bastion" },
        { type = "vpn_gateway" },
        { type = "expressroute_gateway" },
      ]
    }
  }
  assert {
    condition = alltrue([
      contains(keys(output.names), "afw-hub-prd-uks-001"),
      contains(keys(output.names), "bas-hub-prd-uks-001"),
      contains(keys(output.names), "vpng-hub-prd-uks-001"),
      contains(keys(output.names), "ergw-hub-prd-uks-001"),
    ])
    error_message = "hub-only service types missing in (hub, prd)."
  }
}

run "spoke_only_types_in_spoke_npd" {
  command = plan
  variables {
    input = {
      topology    = "spoke"
      tenant      = "sp01"
      environment = "npd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        { type = "function_app" },
        { type = "logic_app" },
        { type = "aml_workspace" },
        { type = "openai" },
        { type = "aifoundry" },
        { type = "language" },
        { type = "doc_intel" },
        { type = "search" },
      ]
    }
  }
  # FR-021 — explicit confusion guard: vnet abbr "vnet" vs vpn_gateway "vpng".
  assert {
    condition = alltrue([
      output.names["func-sp01-npd-uks-001"].service_type == "function_app",
      output.names["oai-sp01-npd-uks-001"].service_type == "openai",
    ])
    error_message = "service_type round-trip violated (FR-021)."
  }
}

run "prd_hub_only_types_in_hub_prd" {
  command = plan
  variables {
    input = {
      topology    = "hub"
      tenant      = "hub"
      environment = "prd"
      region      = "uksouth"
      repo        = "x/y"
      services = [
        { type = "dns_zone" },
        { type = "private_dns_zone" },
      ]
    }
  }
  assert {
    condition = alltrue([
      contains(keys(output.names), "dns-hub-prd-uks-001"),
      contains(keys(output.names), "pdns-hub-prd-uks-001"),
    ])
    error_message = "prd-hub-only DNS types missing in (hub, prd)."
  }
}
