module "apim_public_ip" {
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  name                = var.services.apim.public_ip.name
  location            = var.services.apim.public_ip.location
  resource_group_name = var.services.apim.public_ip.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.services.apim.public_ip.domain_name_label

}

resource "azurerm_api_management" "this" {
  name                = var.services.apim.name
  location            = var.services.apim.location
  resource_group_name = var.services.apim.resource_group_name
  publisher_name      = var.services.apim.publisher_name
  publisher_email     = var.services.apim.publisher_email

  sku_name = var.services.apim.sku.name

  identity {
    type = "SystemAssigned"
  }

  virtual_network_type = var.services.apim.virtual_network_type
  virtual_network_configuration {
    subnet_id = data.azurerm_subnet.this.id
  }
  public_ip_address_id = module.apim_public_ip.public_ip_id
}