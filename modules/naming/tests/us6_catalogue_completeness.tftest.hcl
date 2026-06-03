variables {
  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }
  services = []
  children = []
}

# US6 - the catalogue must contain every service_type listed in spec.md.
# This list mirrors specs/001-naming-convention-engine/spec.md
# "Naming Pattern Table" verbatim; updating either side without the
# other will fail this test (also enforced by the CI script at
# .specify/scripts/bash/check-naming-catalogue.sh).

run "catalogue_completeness" {
  command = plan

  module {
    source = "./catalogue"
  }

  assert {
    condition = length(setsubtract(
      toset([
        # Top-level (30)
        "resource_group", "vnet", "nsg", "route_table", "public_ip",
        "nat_gateway",
        "log_analytics", "app_insights", "storage", "keyvault",
        "container_registry", "container_app_environment", "cosmosdb", "user_assigned_identity", "vm",
        "app_service_plan", "apim", "vpn_gateway", "expressroute_gateway",
        "function_app", "logic_app", "aml_workspace", "openai",
        "aifoundry", "aifoundry_project", "language", "doc_intel", "search",
        "dns_zone", "private_dns_zone",
        # Children (8)
        "subnet", "nsg_rule", "route", "apim_api", "vnet_bastion",
        "vnet_firewall", "private_endpoint", "diagnostic_setting",
      ]),
      toset(keys(output.services))
    )) == 0
    error_message = "Spec lists service_types missing from catalogue: ${jsonencode(setsubtract(
      toset([
        "resource_group", "vnet", "nsg", "route_table", "public_ip",
        "nat_gateway",
        "log_analytics", "app_insights", "storage", "keyvault",
        "container_registry", "container_app_environment", "cosmosdb", "user_assigned_identity", "vm",
        "app_service_plan", "apim", "vpn_gateway", "expressroute_gateway",
        "function_app", "logic_app", "aml_workspace", "openai",
        "aifoundry", "aifoundry_project", "language", "doc_intel", "search",
        "dns_zone", "private_dns_zone",
        "subnet", "nsg_rule", "route", "apim_api", "vnet_bastion",
        "vnet_firewall", "private_endpoint", "diagnostic_setting",
      ]),
      toset(keys(output.services))
    ))}"
  }

  assert {
    condition = length(setsubtract(
      toset(keys(output.services)),
      toset([
        "resource_group", "vnet", "nsg", "route_table", "public_ip",
        "nat_gateway",
        "log_analytics", "app_insights", "storage", "keyvault",
        "container_registry", "container_app_environment", "cosmosdb", "user_assigned_identity", "vm",
        "app_service_plan", "apim", "vpn_gateway", "expressroute_gateway",
        "function_app", "logic_app", "aml_workspace", "openai",
        "aifoundry", "aifoundry_project", "language", "doc_intel", "search",
        "dns_zone", "private_dns_zone",
        "subnet", "nsg_rule", "route", "apim_api", "vnet_bastion",
        "vnet_firewall", "private_endpoint", "diagnostic_setting",
      ])
    )) == 0
    error_message = "Catalogue contains service_types not in spec: ${jsonencode(setsubtract(
      toset(keys(output.services)),
      toset([
        "resource_group", "vnet", "nsg", "route_table", "public_ip",
        "nat_gateway",
        "log_analytics", "app_insights", "storage", "keyvault",
        "container_registry", "container_app_environment", "cosmosdb", "user_assigned_identity", "vm",
        "app_service_plan", "apim", "vpn_gateway", "expressroute_gateway",
        "function_app", "logic_app", "aml_workspace", "openai",
        "aifoundry", "aifoundry_project", "language", "doc_intel", "search",
        "dns_zone", "private_dns_zone",
        "subnet", "nsg_rule", "route", "apim_api", "vnet_bastion",
        "vnet_firewall", "private_endpoint", "diagnostic_setting",
      ])
    ))}"
  }

  assert {
    condition = alltrue([
      for k, v in output.services :
      can(v.abbr) && can(v.shape) && can(v.level)
    ])
    error_message = "Every catalogue row must declare {abbr, shape, level}."
  }

  assert {
    condition = alltrue([
      for k, v in output.services :
      v.level != "top" || can(v.azure_max)
    ])
    error_message = "Every top-level catalogue row must declare azure_max."
  }
}
