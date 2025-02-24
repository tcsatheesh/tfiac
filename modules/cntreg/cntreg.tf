variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = var.vnet.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = var.log.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "private_dns"
  subscription_id = var.dns.subscription_id
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = var.dns.domain_names["containerregistry"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "containerregistry" {
  source                        = "Azure/avm-res-containerregistry-registry/azurerm"
  name                          = var.services.container_registry_name
  location                      = var.services.location
  resource_group_name           = var.services.resource_group_name
  sku                           = "Basic"
  public_network_access_enabled = false
  private_endpoints = {
    primary = {
      name                            = "pe-${var.services.container_registry_name}"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.container_registry_name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.container_registry_name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "tola_${var.services.container_registry_name}"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
