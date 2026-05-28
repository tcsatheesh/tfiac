###############################################################################
# modules/network/locals.tf — subnet role catalogue (FR-208 Q8=A)
###############################################################################

locals {
  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }

  # Intent-driven subnet role catalogue. Caller picks roles + CIDRs;
  # everything else (NSG, route table, delegation, Azure literal name)
  # is decided here.
  subnet_roles = {
    "development" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      delegations       = []
    }
    "pre-production" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      delegations       = []
    }
    "api-management" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = false
      service_endpoints = []
      delegations       = []
    }
    "buildsvr" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = []
      delegations       = []
    }
    "bastion" = {
      azure_subnet_name = "AzureBastionSubnet"
      add_nsg           = true
      add_route_table   = false
      service_endpoints = []
      delegations       = []
    }
    "firewall" = {
      azure_subnet_name = "AzureFirewallSubnet"
      add_nsg           = false
      add_route_table   = false
      service_endpoints = []
      delegations       = []
    }
    "firewall-mgmt" = {
      azure_subnet_name = "AzureFirewallManagementSubnet"
      add_nsg           = false
      add_route_table   = false
      service_endpoints = []
      delegations       = []
    }
    "function-app" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = []
      delegations = [{
        name = "Microsoft.Web.serverFarms"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
        }
      }]
    }
    "logic-app" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = []
      delegations = [{
        name = "Microsoft.Web.serverFarms"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
        }
      }]
    }
    # preprod-* aliases (used by spoke stack) reuse defaults of the
    # base role. Names kept <= 16 chars to satisfy engine purpose regex.
    "preprod-func" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = []
      delegations = [{
        name = "Microsoft.Web.serverFarms"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
        }
      }]
    }
    "preprod-logic" = {
      azure_subnet_name = null
      add_nsg           = true
      add_route_table   = true
      service_endpoints = []
      delegations = [{
        name = "Microsoft.Web.serverFarms"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
        }
      }]
    }
  }

  # Sorted role list — drives deterministic NSG numbering.
  requested_roles = sort(keys(var.subnets))

  # Subset of roles that get a dedicated NSG.
  nsg_roles = [
    for r in local.requested_roles : r
    if local.subnet_roles[r].add_nsg
  ]

  # Subset of roles that get attached to the per-vnet route table.
  rt_roles = [
    for r in local.requested_roles : r
    if local.subnet_roles[r].add_route_table
  ]

  # Engine name lookups (top-level instance #001 of each type).
  rg_name   = "rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  vnet_name = "vnet-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  rt_name   = "rt-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"

  # Per-role subnet canonical name (engine purpose-keyed) — fall back to
  # Azure-mandated literal when the role catalogue demands it.
  subnet_name_for = {
    for r in local.requested_roles :
    r => coalesce(
      local.subnet_roles[r].azure_subnet_name,
      "snet-${r}-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
    )
  }

  # Per-role NSG canonical name (engine numbers nsgs positionally; we use a
  # deterministic role→index map). Naming engine emits
  # nsg-{tenant}-{env}-{region_code}-NNN; we follow the same scheme here.
  nsg_index_for = {
    for idx, r in local.nsg_roles : r => idx + 1
  }

  nsg_name_for = {
    for r, i in local.nsg_index_for :
    r => format("nsg-%s-%s-%s-%03d", var.input.tenant, var.input.environment, var.region_code, i)
  }
}
