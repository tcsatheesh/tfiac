###############################################################################
# Service catalogue (top-level)
# Sources:
#   - FR-026 inventory table (authoritative).
#   - FR-010 region table.
#   - FR-012 default-settings catalogue.
# CAF abbreviations are pinned per FR-036.
#
# Adding a row here is a single-PR catalogue edit (Constitution V).
###############################################################################

locals {
  # Top-level service catalogue. Keyed by service_type. Every row carries
  # everything the engine needs to shape, validate, and tag the service.
  services = {
    # ─── general ────────────────────────────────────────────────────────────
    resource_group = {
      caf_abbr               = "rg"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 90
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = []
    }
    vnet = {
      caf_abbr               = "vnet"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 64
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["subnets", "diagnostic_settings"]
    }
    nsg = {
      caf_abbr               = "nsg"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["nsg_rules", "diagnostic_settings"]
    }
    route_table = {
      caf_abbr               = "rt"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["routes"]
    }
    public_ip = {
      caf_abbr               = "pip"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    log_analytics = {
      caf_abbr               = "log"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 63
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    app_insights = {
      caf_abbr               = "appi"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 260
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    storage = {
      caf_abbr               = "st"
      shape                  = "concatenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 24
      charset                = "alphanumeric"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    keyvault = {
      caf_abbr               = "kv"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 24
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    container_registry = {
      caf_abbr               = "cr"
      shape                  = "concatenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 50
      charset                = "alphanumeric"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    user_assigned_identity = {
      caf_abbr               = "id"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 128
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = []
    }
    vm = {
      caf_abbr               = "vm"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 64
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    app_service_plan = {
      caf_abbr               = "asp"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 60
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    apim = {
      caf_abbr               = "apim"
      shape                  = "hyphenated"
      topology_scope         = "either"
      category               = "top-level"
      max_length             = 50
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    # ─── hub-only ───────────────────────────────────────────────────────────
    firewall = {
      caf_abbr               = "afw"
      shape                  = "hyphenated"
      topology_scope         = "hub-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    bastion = {
      caf_abbr               = "bas"
      shape                  = "hyphenated"
      topology_scope         = "hub-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    vpn_gateway = {
      caf_abbr               = "vpng"
      shape                  = "hyphenated"
      topology_scope         = "hub-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    expressroute_gateway = {
      caf_abbr               = "ergw"
      shape                  = "hyphenated"
      topology_scope         = "hub-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    # ─── spoke-only ─────────────────────────────────────────────────────────
    function_app = {
      caf_abbr               = "func"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 60
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    logic_app = {
      caf_abbr               = "logic"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["diagnostic_settings"]
    }
    aml_workspace = {
      caf_abbr               = "mlw"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 33
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    openai = {
      caf_abbr               = "oai"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 64
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    aifoundry = {
      caf_abbr               = "aif"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 64
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    language = {
      caf_abbr               = "lang"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 64
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    doc_intel = {
      caf_abbr               = "di"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 64
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    search = {
      caf_abbr               = "srch"
      shape                  = "hyphenated"
      topology_scope         = "spoke-only"
      category               = "top-level"
      max_length             = 60
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = ["private_endpoints", "diagnostic_settings"]
    }
    # ─── prd-hub-only ───────────────────────────────────────────────────────
    dns_zone = {
      caf_abbr               = "dns"
      shape                  = "hyphenated"
      topology_scope         = "prd-hub-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = []
    }
    private_dns_zone = {
      caf_abbr               = "pdns"
      shape                  = "hyphenated"
      topology_scope         = "prd-hub-only"
      category               = "top-level"
      max_length             = 80
      charset                = "alphanumeric-hyphen"
      case_rule              = "lowercase"
      must_start_with_letter = true
      child_keys             = []
    }
  }

  # Child-only catalogue (FR-027, FR-028).
  # parent_allowlist: set of permitted parent service_types ("*" means "any
  # top-level row whose child_keys list contains this child's child_list_key").
  # numbering: "positional" or "purpose-keyed".
  child_types = {
    subnet = {
      caf_abbr         = "snet"
      child_list_key   = "subnets"
      numbering        = "purpose-keyed"
      parent_allowlist = ["vnet"]
    }
    nsg_rule = {
      caf_abbr         = "nsgrule"
      child_list_key   = "nsg_rules"
      numbering        = "purpose-keyed"
      parent_allowlist = ["nsg"]
    }
    route = {
      caf_abbr         = "udr"
      child_list_key   = "routes"
      numbering        = "purpose-keyed"
      parent_allowlist = ["route_table"]
    }
    private_endpoint = {
      caf_abbr         = "pep"
      child_list_key   = "private_endpoints"
      numbering        = "positional"
      parent_allowlist = ["storage", "keyvault", "container_registry", "apim", "function_app", "aml_workspace", "openai", "aifoundry", "language", "doc_intel", "search"]
    }
    diagnostic_setting = {
      caf_abbr         = "diag"
      child_list_key   = "diagnostic_settings"
      numbering        = "positional"
      parent_allowlist = ["vnet", "nsg", "public_ip", "log_analytics", "app_insights", "storage", "keyvault", "container_registry", "vm", "app_service_plan", "apim", "firewall", "bastion", "vpn_gateway", "expressroute_gateway", "function_app", "logic_app", "aml_workspace", "openai", "aifoundry", "language", "doc_intel", "search"]
    }
  }

  # Region short-code catalogue (FR-010, day-one).
  region_codes = {
    uksouth     = "uks"
    ukwest      = "ukw"
    westeurope  = "weu"
    northeurope = "neu"
    eastus      = "eus"
    eastus2     = "eus2"
    westus2     = "wus2"
    westus3     = "wus3"
  }

  # Default-settings catalogue per top-level service_type (FR-012).
  # Each entry is the minimum-deployable shape; consumers override per record
  # via var.input.overrides[canonical_name].
  defaults = {
    resource_group         = { managed_by_engine = true }
    vnet                   = { address_space = ["10.0.0.0/16"] }
    nsg                    = { default_rules = true }
    route_table            = { disable_bgp_route_propagation = false }
    public_ip              = { allocation_method = "Static", sku = "Standard" }
    log_analytics          = { sku = "PerGB2018", retention_in_days = 30 }
    app_insights           = { application_type = "web" }
    storage                = { account_tier = "Standard", account_replication_type = "LRS" }
    keyvault               = { sku = "standard", purge_protection_enabled = true }
    container_registry     = { sku = "Standard", admin_enabled = false }
    user_assigned_identity = {}
    vm                     = { size = "Standard_D2s_v5", os_type = "Linux" }
    app_service_plan       = { sku = "P1v3", os_type = "Linux" }
    apim                   = { sku_name = "Developer_1" }
    firewall               = { sku_tier = "Standard" }
    bastion                = { sku = "Standard" }
    vpn_gateway            = { sku = "VpnGw2", type = "Vpn" }
    expressroute_gateway   = { sku = "Standard" }
    function_app           = { runtime = "python", runtime_version = "3.11" }
    logic_app              = { workflow_schema = "2019-05-01" }
    aml_workspace          = { sku = "Basic" }
    openai                 = { sku_name = "S0" }
    aifoundry              = { sku_name = "S0" }
    language               = { sku_name = "S" }
    doc_intel              = { sku_name = "S0" }
    search                 = { sku = "standard", replica_count = 1, partition_count = 1 }
    dns_zone               = {}
    private_dns_zone       = {}
  }
}
