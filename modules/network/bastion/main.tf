###############################################################################
# modules/network/bastion/main.tf — Azure Bastion via AVM.
# Wraps:
#   * Azure/avm-res-network-publicipaddress/azurerm  0.2.1
#   * Azure/avm-res-network-bastionhost/azurerm      0.9.0
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
variable "resource_group_id" { type = string }
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

module "pip" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "0.2.1"

  name                = local.pip_name
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.baseline_tags, { role = "bastion-pip" })
  enable_telemetry    = false
}

module "bastion" {
  source  = "Azure/avm-res-network-bastionhost/azurerm"
  version = "0.9.0"

  name             = local.bastion_name
  location         = var.region
  parent_id        = var.resource_group_id
  sku              = "Standard"
  tags             = local.baseline_tags
  enable_telemetry = false

  ip_configuration = {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    create_public_ip     = false
    public_ip_address_id = module.pip.resource_id
  }
}

output "bastion_id" { value = module.bastion.resource_id }
output "bastion_name" { value = local.bastion_name }
output "public_ip_id" { value = module.pip.resource_id }
