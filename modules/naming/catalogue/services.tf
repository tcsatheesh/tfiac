# Service catalogue - single source of truth for naming-engine resource types.
#
# Source of record: specs/001-naming-convention-engine/spec.md "Naming Pattern Table".
# Adding/removing a row here MUST be accompanied by the same change in spec.md
# (enforced by tests/us6_catalogue_completeness.tftest.hcl and the CI script
# at .specify/scripts/bash/check-naming-catalogue.sh).
#
# Fields:
#   abbr        - CAF short code used as the leading token in the name.
#   shape       - composition style; one of:
#                   "hyphenated"    {abbr}-{p}-{usecase}-{tenant}-{environment}-{region}-{instance}
#                   "concatenated"  {abbr}{p}{usecase}{tenant}{environment}{region}{instance}
#                   "rg_hyphenated" rg-{stack_purpose}-{usecase}-{tenant}-{environment}-{region}-{instance}
#                   "fqdn"          caller-supplied FQDN, used verbatim
#                   "child_purpose" {abbr}-{child_purpose}-{P}
#                   "singleton"     {abbr}-{P}                 (max 1 per parent)
#                   "positional"    {abbr}-{P}-{instance}      (per parent)
#   azure_max   - per-Azure name-length limit (chars).
#   level       - "top" or "child".
#   parent_type - children only: the parent service_type, or "*" for any parent.

locals {
  services = {
    # ----- Top-level resources (30 rows) -----
    "resource_group" = { abbr = "rg", shape = "rg_hyphenated", azure_max = 90, level = "top" }
    "vnet"           = { abbr = "vnet", shape = "hyphenated", azure_max = 64, level = "top" }
    "nsg"            = { abbr = "nsg", shape = "hyphenated", azure_max = 80, level = "top" }
    "route_table"    = { abbr = "rt", shape = "hyphenated", azure_max = 80, level = "top" }
    "public_ip"      = { abbr = "pip", shape = "hyphenated", azure_max = 80, level = "top" }
    # nat_gateway (Amendment 2026-06-03, FR-229) — Azure NAT Gateway. CAF abbr
    # `ng`; hyphenated shape. Provides firewall-independent subnet egress.
    "nat_gateway"               = { abbr = "ng", shape = "hyphenated", azure_max = 80, level = "top" }
    "log_analytics"             = { abbr = "log", shape = "hyphenated", azure_max = 63, level = "top" }
    "app_insights"              = { abbr = "appi", shape = "hyphenated", azure_max = 260, level = "top" }
    "storage"                   = { abbr = "st", shape = "concatenated", azure_max = 24, level = "top" }
    "keyvault"                  = { abbr = "kv", shape = "concatenated", azure_max = 24, level = "top" }
    "container_registry"        = { abbr = "cr", shape = "concatenated", azure_max = 50, level = "top" }
    "container_app_environment" = { abbr = "cae", shape = "hyphenated", azure_max = 32, level = "top" }
    # cosmosdb (Amendment 2026-06-02, FR-032) — Azure Cosmos DB account. Name 3-44
    # chars, lowercase alnum + hyphen. CAF abbr `cosmos`; hyphenated shape.
    "cosmosdb"               = { abbr = "cosmos", shape = "hyphenated", azure_max = 44, level = "top" }
    "user_assigned_identity" = { abbr = "id", shape = "hyphenated", azure_max = 128, level = "top" }
    "vm"                     = { abbr = "vm", shape = "hyphenated", azure_max = 64, level = "top" }
    "app_service_plan"       = { abbr = "asp", shape = "hyphenated", azure_max = 40, level = "top" }
    "apim"                   = { abbr = "apim", shape = "hyphenated", azure_max = 50, level = "top" }
    "vpn_gateway"            = { abbr = "vpng", shape = "hyphenated", azure_max = 80, level = "top" }
    "expressroute_gateway"   = { abbr = "ergw", shape = "hyphenated", azure_max = 80, level = "top" }
    "function_app"           = { abbr = "func", shape = "hyphenated", azure_max = 60, level = "top" }
    "logic_app"              = { abbr = "logic", shape = "hyphenated", azure_max = 80, level = "top" }
    "aml_workspace"          = { abbr = "mlw", shape = "hyphenated", azure_max = 33, level = "top" }
    "openai"                 = { abbr = "oai", shape = "hyphenated", azure_max = 64, level = "top" }
    "aifoundry"              = { abbr = "aif", shape = "hyphenated", azure_max = 64, level = "top" }
    "aifoundry_project"      = { abbr = "aifp", shape = "hyphenated", azure_max = 32, level = "top" }
    "language"               = { abbr = "lang", shape = "hyphenated", azure_max = 64, level = "top" }
    "doc_intel"              = { abbr = "di", shape = "hyphenated", azure_max = 64, level = "top" }
    "search"                 = { abbr = "srch", shape = "hyphenated", azure_max = 60, level = "top" }
    "dns_zone"               = { abbr = "", shape = "fqdn", azure_max = 253, level = "top" }
    "private_dns_zone"       = { abbr = "", shape = "fqdn", azure_max = 253, level = "top" }

    # ----- Child resources (8 rows) -----
    "subnet"             = { abbr = "snet", shape = "child_purpose", azure_max = 80, level = "child", parent_type = "vnet" }
    "nsg_rule"           = { abbr = "nsgrule", shape = "child_purpose", azure_max = 80, level = "child", parent_type = "nsg" }
    "route"              = { abbr = "udr", shape = "child_purpose", azure_max = 80, level = "child", parent_type = "route_table" }
    "apim_api"           = { abbr = "api", shape = "child_purpose", azure_max = 80, level = "child", parent_type = "apim" }
    "vnet_bastion"       = { abbr = "bas", shape = "singleton", azure_max = 80, level = "child", parent_type = "vnet" }
    "vnet_firewall"      = { abbr = "afw", shape = "singleton", azure_max = 80, level = "child", parent_type = "vnet" }
    "private_endpoint"   = { abbr = "pep", shape = "positional", azure_max = 80, level = "child", parent_type = "*" }
    "diagnostic_setting" = { abbr = "diag", shape = "positional", azure_max = 260, level = "child", parent_type = "*" }
  }
}
