# AVM bastion module creates its own PIP when create_public_ip = true.
# We pass the engine-emitted PIP name via public_ip_address_name so the
# resource is named consistently.

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
    name                             = "ipconfig"
    subnet_id                        = var.subnet_id
    create_public_ip                 = true
    public_ip_address_name           = var.public_ip_name
    public_ip_merge_with_module_tags = true
  }
}
