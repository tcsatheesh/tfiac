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

# We need the tenant id for the key vault.
data "azurerm_client_config" "this" {}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = var.dns.domain_names["keyvault"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

# This is the module call
module "keyvault" {
  source                        = "Azure/avm-res-keyvault-vault/azurerm"
  name                          = var.services.key_vault_name
  location                      = var.services.location
  resource_group_name           = var.services.resource_group_name
  tenant_id                     = data.azurerm_client_config.this.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = var.services.purge_protection_enabled
  public_network_access_enabled = var.services.public_network_access_enabled
  private_endpoints = {
    pe_endpoint = {
      name                          = "pe-${var.services.key_vault_name}"
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.this.id]
      subnet_resource_id            = data.azurerm_subnet.this.id
      resource_group_name           = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "tola_${var.services.key_vault_name}"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
