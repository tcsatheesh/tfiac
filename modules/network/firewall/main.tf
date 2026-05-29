###############################################################################
# modules/network/firewall/main.tf — Azure Firewall via AVM.
# Wraps:
#   * Azure/avm-res-network-publicipaddress/azurerm      0.2.1  (data + mgmt PIPs)
#   * Azure/avm-res-network-azurefirewall/azurerm        0.4.0
# `azurerm_firewall_policy` is kept bare (no published AVM module that we
# require here; revisit if avm-res-network-firewallpolicy adoption increases).
###############################################################################

variable "region" { type = string }
variable "region_code" { type = string }
variable "input" {
  type = object({
    topology    = string
    tenant      = string
    environment = string
    region      = string
    repo        = string
  })
}
variable "resource_group_name" { type = string }
variable "firewall_subnet_id" { type = string }
variable "firewall_mgmt_subnet_id" { type = string }

locals {
  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }

  fw_name       = "afw-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  policy_name   = "afwp-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  data_pip_name = "pip-${var.input.tenant}-${var.input.environment}-${var.region_code}-002"
  mgmt_pip_name = "pip-${var.input.tenant}-${var.input.environment}-${var.region_code}-003"
}

module "pip_data" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "0.2.1"

  name                = local.data_pip_name
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.baseline_tags, { role = "firewall-data-pip" })
  enable_telemetry    = false
}

module "pip_mgmt" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "0.2.1"

  name                = local.mgmt_pip_name
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.baseline_tags, { role = "firewall-mgmt-pip" })
  enable_telemetry    = false
}

resource "azurerm_firewall_policy" "this" {
  name                = local.policy_name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  tags                = local.baseline_tags
}

module "firewall" {
  source  = "Azure/avm-res-network-azurefirewall/azurerm"
  version = "0.4.0"

  name                = local.fw_name
  location            = var.region
  resource_group_name = var.resource_group_name
  firewall_sku_name   = "AZFW_VNet"
  firewall_sku_tier   = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  firewall_zones      = []
  tags                = local.baseline_tags
  enable_telemetry    = false

  ip_configurations = {
    "configuration" = {
      name                 = "configuration"
      subnet_id            = var.firewall_subnet_id
      public_ip_address_id = module.pip_data.resource_id
    }
  }

  firewall_management_ip_configuration = {
    name                 = "mgmt"
    subnet_id            = var.firewall_mgmt_subnet_id
    public_ip_address_id = module.pip_mgmt.resource_id
  }
}

output "firewall_id" { value = module.firewall.resource_id }
output "firewall_name" { value = local.fw_name }
output "firewall_policy_id" { value = azurerm_firewall_policy.this.id }
output "private_ip" {
  description = "Firewall data plane private IP (use as default route next hop)."
  value       = module.firewall.resource.ip_configuration[0].private_ip_address
}
output "data_public_ip_id" { value = module.pip_data.resource_id }
output "mgmt_public_ip_id" { value = module.pip_mgmt.resource_id }
