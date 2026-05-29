###############################################################################
# modules/network/locals.tf — subnet role catalogue + AVM-friendly NSG rules.
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

  # RG carries an optional `purpose` segment (matches modules/loganalytics +
  # modules/dnszones precedent: rg-<tenant>-<env>-[<purpose>-]<region>-001).
  rg_name = (
    try(var.input.purpose, null) == null
    ? "rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
    : "rg-${var.input.tenant}-${var.input.environment}-${var.input.purpose}-${var.region_code}-001"
  )
  vnet_name = "vnet-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  rt_name   = "rt-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"

  subnet_name_for = {
    for r in local.requested_roles :
    r => coalesce(
      local.subnet_roles[r].azure_subnet_name,
      "snet-${r}-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
    )
  }

  nsg_index_for = {
    for idx, r in local.nsg_roles : r => idx + 1
  }

  nsg_name_for = {
    for r, i in local.nsg_index_for :
    r => format("nsg-%s-%s-%s-%03d", var.input.tenant, var.input.environment, var.region_code, i)
  }

  # Baseline NSG rules required by Azure for AzureBastionSubnet. All rules
  # carry every optional attribute (with `null`) so the resulting map has a
  # uniform object shape — that lets the ternary in nsg_security_rules_for
  # unify the bastion-vs-non-bastion arms with an empty map.
  bastion_baseline_rules = [
    { name = "AllowHttpsInbound", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "Internet", destination_address_prefix = "*" },
    { name = "AllowGatewayManagerInbound", priority = 130, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "GatewayManager", destination_address_prefix = "*" },
    { name = "AllowLoadBalancerInbound", priority = 140, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*" },
    { name = "AllowBastionHostCommunication", priority = 150, direction = "Inbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork" },
    { name = "AllowSshRdpOutbound", priority = 100, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["22", "3389"], source_address_prefix = "*", destination_address_prefix = "VirtualNetwork" },
    { name = "AllowAzureCloudOutbound", priority = 110, direction = "Outbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "*", destination_address_prefix = "AzureCloud" },
    { name = "AllowBastionCommunicationOutbound", priority = 120, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork" },
    { name = "AllowGetSessionInformation", priority = 130, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["80"], source_address_prefix = "*", destination_address_prefix = "Internet" },
  ]

  # Bastion baseline rules pre-keyed by name (AVM `security_rules` map shape).
  bastion_baseline_rules_map = {
    for rule in local.bastion_baseline_rules : rule.name => rule
  }

  # Per-role NSG rule map keyed by rule name (AVM `security_rules` shape).
  # Bastion gets the Azure baseline; every role can layer extras via
  # var.extra_nsg_rules.
  nsg_security_rules_for = {
    for r in local.nsg_roles :
    r => merge(
      r == "bastion" ? local.bastion_baseline_rules_map : {},
      { for rule in try(var.extra_nsg_rules[r], []) : rule.name => rule },
    )
  }
}
