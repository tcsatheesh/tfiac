# Data-plane PIP for the firewall.
module "pip_data" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "~> 0.2"

  name                = var.data_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.pip_data_tags
  enable_telemetry    = false
}

# Management-plane PIP (required for Standard tier with forced tunnelling or
# always required for Basic; we keep it always-on so the firewall can be
# upgraded/downgraded without recreation).
module "pip_mgmt" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "~> 0.2"

  name                = var.mgmt_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.pip_mgmt_tags
  enable_telemetry    = false
}

# Empty Standard policy (spec C5: empty firewall policy day-one).
resource "azurerm_firewall_policy" "this" {
  name                = format("afwp-%s", var.name)
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags
}

module "firewall" {
  source  = "Azure/avm-res-network-azurefirewall/azurerm"
  version = "~> 0.4"

  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  firewall_sku_name   = "AZFW_VNet"
  firewall_sku_tier   = "Standard"
  firewall_zones      = ["1", "2", "3"]
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags
  enable_telemetry    = false

  ip_configurations = {
    data = {
      name                 = "ipconfig-data"
      public_ip_address_id = module.pip_data.public_ip_id
      subnet_id            = var.data_subnet_id
    }
  }

  firewall_management_ip_configuration = {
    name                 = "ipconfig-mgmt"
    public_ip_address_id = module.pip_mgmt.public_ip_id
    subnet_id            = var.mgmt_subnet_id
  }
}
