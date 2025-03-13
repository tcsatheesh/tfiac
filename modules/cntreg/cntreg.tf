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

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["containerregistry"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "containerregistry" {
  source                        = "Azure/avm-res-containerregistry-registry/azurerm"
  name                          = var.services.container_registry.name
  location                      = var.services.location
  resource_group_name           = var.services.resource_group_name
  sku                           = "Premium"
  zone_redundancy_enabled       = false
  retention_policy_in_days      = 7
  public_network_access_enabled = false # public_network_access_enabled can only be disabled for Premium SKU
  private_endpoints = {
    primary = {
      name                            = "pe-${var.services.container_registry.name}"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.container_registry.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.container_registry.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "tola_${var.services.container_registry.name}"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}

output "container_registry_id" {
  value = module.containerregistry.resource_id
}