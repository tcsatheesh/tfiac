variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      configuration_aliases = [
        azurerm.services,
        azurerm.log,
        azurerm.vnet,
      azurerm.dns]
    }
  }
}


data "azurerm_virtual_network" "this" {
  provider            = azurerm.vnet
  name                = var.vnet.name
  resource_group_name = var.vnet.resource_group_name
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["aisearch"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

# Create Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  provider              = azurerm.dns
  name                  = "${var.vnet.name}-link"
  private_dns_zone_name = data.azurerm_private_dns_zone.this.name
  resource_group_name   = var.dns.resource_group_name
  virtual_network_id    = data.azurerm_virtual_network.this.id
}

module "search_service" {
  source              = "Azure/avm-res-search-searchservice/azurerm"
  location            = var.services.location
  name                = var.services.ai_search.name
  resource_group_name = var.services.resource_group_name
  private_endpoints = {
    primary = {
      name                            = "pe-${var.services.ai_search.name}"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.ai_search.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.ai_search.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }

  sku                           = "standard"
  public_network_access_enabled = false
  local_authentication_enabled  = false
  managed_identities = {
    system_assigned = true
  }
}

