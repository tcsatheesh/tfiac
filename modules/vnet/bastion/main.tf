module "fw_public_ip" {
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  name                = var.vnet.bastion.public_ip.name
  location            = var.vnet.bastion.location
  resource_group_name = var.vnet.bastion.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  enable_telemetry    = false
}


####################################################
# bastion host
####################################################

resource "azurerm_bastion_host" "azure_bastion_instance" {
  name                = var.vnet.bastion.name
  location            = var.vnet.bastion.location
  resource_group_name = var.vnet.bastion.resource_group_name
  sku                 = "Developer"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = module.fw_public_ip.public_ip_id
  }
}