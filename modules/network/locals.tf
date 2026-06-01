# Subnet role catalogue + naming-engine intent construction.

locals {
  # ----- Subnet role catalogue (research D11 + spec § Subnet role catalogue) -----
  role_catalogue = {
    "development" = {
      abbr3             = "dev"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      delegation        = []
    }
    "pre-production" = {
      abbr3             = "pre"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      delegation        = []
    }
    "api-management" = {
      abbr3             = "api"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = false
      service_endpoints = []
      delegation        = []
    }
    "buildsvr" = {
      abbr3             = "bld"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = []
      delegation        = []
    }
    "function-app" = {
      abbr3             = "fnc"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = []
      delegation        = ["Microsoft.Web/serverFarms"]
    }
    "logic-app" = {
      abbr3             = "lgc"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = []
      delegation        = ["Microsoft.Web/serverFarms"]
    }
    "preprod-func" = {
      abbr3             = "pfn"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = []
      delegation        = ["Microsoft.Web/serverFarms"]
    }
    "preprod-logic" = {
      abbr3             = "plg"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = true
      service_endpoints = []
      delegation        = ["Microsoft.Web/serverFarms"]
    }
    "container-apps" = {
      abbr3             = "cae"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = false
      service_endpoints = []
      delegation        = ["Microsoft.App/environments"]
    }
    # FR-226 (Amendment 2026-06-02) — dedicated Foundry Hosted-Agent subnet
    # (VC-5). Delegated to Microsoft.App/environments like `container-apps`,
    # but a DISTINCT role so a spoke can carry both an ACA managed-environment
    # subnet (`cae`) and a separate, exclusive agent subnet (`agt`). Recommended
    # /24; the CIDR is supplied per-instance via var.subnets. No route table
    # (the managed environment handles its own egress).
    "agents" = {
      abbr3             = "agt"
      literal_name      = null
      needs_nsg         = true
      needs_route_table = false
      service_endpoints = []
      delegation        = ["Microsoft.App/environments"]
    }
    "bastion" = {
      abbr3             = "bas"
      literal_name      = "AzureBastionSubnet"
      needs_nsg         = true
      needs_route_table = false
      service_endpoints = []
      delegation        = []
    }
    "firewall" = {
      abbr3             = "afw"
      literal_name      = "AzureFirewallSubnet"
      needs_nsg         = false
      needs_route_table = false
      service_endpoints = []
      delegation        = []
    }
    "firewall-mgmt" = {
      abbr3             = "afm"
      literal_name      = "AzureFirewallManagementSubnet"
      needs_nsg         = false
      needs_route_table = false
      service_endpoints = []
      delegation        = []
    }
  }

  # Sorted role list for deterministic iteration in fixtures.
  active_roles    = sort(keys(var.subnets))
  nsg_roles       = sort([for r in local.active_roles : r if try(local.role_catalogue[r].needs_nsg, false)])
  rt_attach_roles = sort([for r in local.active_roles : r if try(local.role_catalogue[r].needs_route_table, false)])

  # ----- Engine intent -----
  engine_services = concat(
    [{ service_type = "resource_group", key = "rg", stack_purpose = "net" }],
    [{ service_type = "vnet", key = "main", service_purpose = "net" }],
    [{ service_type = "route_table", key = "rt", service_purpose = "net" }],
    [
      for r in local.nsg_roles : {
        service_type    = "nsg"
        key             = local.role_catalogue[r].abbr3
        service_purpose = local.role_catalogue[r].abbr3
      }
    ],
    var.role == "hub" ? [
      { service_type = "public_ip", key = "bas", service_purpose = "bas" },
      { service_type = "public_ip", key = "afw", service_purpose = "afw" },
      { service_type = "public_ip", key = "afm", service_purpose = "afm" },
    ] : [],
  )

  engine_children = concat(
    [
      for r in local.active_roles : {
        service_type  = "subnet"
        parent_key    = "main"
        key           = local.role_catalogue[r].abbr3
        child_purpose = local.role_catalogue[r].abbr3
      }
    ],
    var.role == "hub" ? [
      { service_type = "vnet_bastion", parent_key = "main", key = "bas" },
      { service_type = "vnet_firewall", parent_key = "main", key = "afw" },
    ] : [],
  )

  # ----- Locally-computed canonical names (plan-time-known; mirror engine output) -----
  rg_canonical_name = format(
    "rg-net-%s-%s-%s-%s-001",
    var.input.usecase, var.input.tenant, var.input.environment, var.input.region,
  )

  vnet_canonical_name = format(
    "vnet-net-%s-%s-%s-%s-001",
    var.input.usecase, var.input.tenant, var.input.environment, var.input.region,
  )

  rt_canonical_name = format(
    "rt-net-%s-%s-%s-%s-001",
    var.input.usecase, var.input.tenant, var.input.environment, var.input.region,
  )

  nsg_canonical_names = {
    for r in local.nsg_roles : r =>
    format(
      "nsg-%s-%s-%s-%s-%s-001",
      local.role_catalogue[r].abbr3,
      var.input.usecase, var.input.tenant, var.input.environment, var.input.region,
    )
  }

  # Bastion/firewall canonical names follow the `singleton` shape:
  # "<abbr>-<parent_tuple>" where parent_tuple is the vnet tuple.
  vnet_parent_tuple = format(
    "vnet-net-%s-%s-%s-%s-001",
    var.input.usecase, var.input.tenant, var.input.environment, var.input.region,
  )

  bastion_canonical_name  = format("bas-%s", local.vnet_parent_tuple)
  firewall_canonical_name = format("afw-%s", local.vnet_parent_tuple)

  pip_canonical_names = {
    bas = format("pip-bas-%s-%s-%s-%s-001", var.input.usecase, var.input.tenant, var.input.environment, var.input.region)
    afw = format("pip-afw-%s-%s-%s-%s-001", var.input.usecase, var.input.tenant, var.input.environment, var.input.region)
    afm = format("pip-afm-%s-%s-%s-%s-001", var.input.usecase, var.input.tenant, var.input.environment, var.input.region)
  }

  # Subnet canonical names per role (child_purpose shape).
  # Engine output: "snet-<child_purpose>-<vnet_parent_tuple>"
  subnet_canonical_names = {
    for r in local.active_roles : r =>
    coalesce(
      local.role_catalogue[r].literal_name,
      format("snet-%s-%s", local.role_catalogue[r].abbr3, local.vnet_parent_tuple),
    )
  }

  # Azure long-form region.
  region_full = module.naming.names[local.rg_canonical_name].tags.region

  # ----- Service-endpoint per-region location tables (FR-225 / C16.16) -----
  # Azure normalises `locations = ["*"]` to the regional pair for some
  # endpoints (e.g. Microsoft.Storage). To keep `terraform plan` idempotent
  # we declare the explicit list per region. Unmapped regions fall back to
  # ["*"] via lookup(..., ["*"]) in main.tf — that preserves today's
  # behaviour and any resulting drift will surface at the next Phase gate.
  storage_se_locations = {
    swedencentral = ["swedencentral", "swedensouth"]
  }
}
