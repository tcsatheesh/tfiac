###############################################################################
# modules/network/firewall/main.tf — Azure Firewall + data PIP + mgmt PIP.
# Uses an empty firewall_policy (Standard tier). Rule collections are
# deferred (feature 005).
###############################################################################

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      configuration_aliases = []
    }
  }
}

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

resource "azurerm_public_ip" "data" {
  name                = local.data_pip_name
  resource_group_name = var.resource_group_name
  location            = var.region
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.baseline_tags, { role = "firewall-data-pip" })
}

resource "azurerm_public_ip" "mgmt" {
  name                = local.mgmt_pip_name
  resource_group_name = var.resource_group_name
  location            = var.region
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.baseline_tags, { role = "firewall-mgmt-pip" })
}

resource "azurerm_firewall_policy" "this" {
  name                = local.policy_name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  tags                = local.baseline_tags
}

resource "azurerm_firewall" "this" {
  name                = local.fw_name
  location            = var.region
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = local.baseline_tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.data.id
  }

  management_ip_configuration {
    name                 = "mgmt"
    subnet_id            = var.firewall_mgmt_subnet_id
    public_ip_address_id = azurerm_public_ip.mgmt.id
  }
}

output "firewall_id" { value = azurerm_firewall.this.id }
output "firewall_name" { value = azurerm_firewall.this.name }
output "firewall_policy_id" { value = azurerm_firewall_policy.this.id }
output "private_ip" {
  description = "Firewall data plane private IP (use as default route next hop)."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
output "data_public_ip_id" { value = azurerm_public_ip.data.id }
output "mgmt_public_ip_id" { value = azurerm_public_ip.mgmt.id }
