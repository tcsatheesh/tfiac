# Bastion data-plane PIP. Created OUTSIDE the bastion AVM module so we can
# set `ip_tags = { FirstPartyUsage = "/Unprivileged" }` (FR-223 / C16.14).
# The bastion AVM's embedded PIP submodule does not expose ip_tags, so we
# pass our PIP id in via `create_public_ip = false` + `public_ip_address_id`
# (FR-224 / C16.15). Re-exported via output "pip_ip_tags" so plan-time
# tests can assert it (T129).
locals {
  first_party_pip_ip_tags = { FirstPartyUsage = "/Unprivileged" }
}

module "pip" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "~> 0.2"

  name                = var.public_ip_name
  location            = var.location
  resource_group_name = split("/", var.resource_group_id)[4]
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  ip_tags             = local.first_party_pip_ip_tags
  tags                = var.public_ip_tags
  enable_telemetry    = false
}

module "bastion" {
  source  = "Azure/avm-res-network-bastionhost/azurerm"
  version = "~> 0.4"

  name             = var.name
  location         = var.location
  parent_id        = var.resource_group_id
  sku              = "Standard"
  enable_telemetry = false
  tags             = var.tags

  ip_configuration = {
    name                 = "ipconfig"
    subnet_id            = var.subnet_id
    create_public_ip     = false
    public_ip_address_id = module.pip.public_ip_id
  }
}
