###############################################################################
# modules/network/bastion/main.tf — Azure Bastion + PIP.
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
variable "subnet_id" { type = string }

locals {
  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }

  bastion_name = "bas-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  pip_name     = "pip-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
}

resource "azurerm_public_ip" "bastion" {
  name                = local.pip_name
  resource_group_name = var.resource_group_name
  location            = var.region
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.baseline_tags, { role = "bastion-pip" })
}

resource "azurerm_bastion_host" "this" {
  name                = local.bastion_name
  location            = var.region
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = local.baseline_tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

output "bastion_id" { value = azurerm_bastion_host.this.id }
output "bastion_name" { value = azurerm_bastion_host.this.name }
output "public_ip_id" { value = azurerm_public_ip.bastion.id }
