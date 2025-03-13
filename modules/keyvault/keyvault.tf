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


# We need the tenant id for the key vault.
data "azurerm_client_config" "this" {}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["keyvault"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

# This is the module call
module "keyvault" {
  source                        = "Azure/avm-res-keyvault-vault/azurerm"
  name                          = var.services.key_vault.name
  location                      = var.services.location
  resource_group_name           = var.services.resource_group_name
  tenant_id                     = data.azurerm_client_config.this.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = var.services.key_vault.purge_protection_enabled
  public_network_access_enabled = var.services.key_vault.public_network_access_enabled
  private_endpoints = {
    pe_endpoint = {
      name                            = "pe-${var.services.key_vault.name}"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.key_vault.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.key_vault.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "tola_${var.services.key_vault.name}"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}

output "keyvault_id" {
  value = module.keyvault.resource_id
}
