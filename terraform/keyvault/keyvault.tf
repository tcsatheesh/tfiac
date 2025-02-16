variable "key_vault_name" {
  type = string
}
variable "enable_telemetry" {
  type    = bool
  default = true
}
variable "location" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "virtual_network_resource_group_name" {
  type = string
}
variable "virtual_network_name" {
  type = string
}
variable "subnet_name" {
  type = string
}
variable "dns_subscription_id" {
  type = string
}
variable "dns_resource_group_name" {
  type = string
}
variable "private_dns_zone_name" {
  type    = string
  default = "privatelink.vaultcore.azure.net"
}
variable "public_network_access_enabled" {
  type    = bool
  default = false
}
variable "purge_protection_enabled" {
  type    = bool
  default = false
}
variable "log_analytics_workspace_name" {
  type = string
}
variable "log_analytics_workspace_subscription_id" {
  type = string
}
variable "log_analytics_workspace_resource_group_name" {
  type = string
}

terraform {
  required_version = "~> 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  features {
  }
  alias           = "log_analytics_workspace"
  subscription_id = var.log_analytics_workspace_subscription_id
}

provider "azurerm" {
  features {}
  alias           = "private_dns"
  subscription_id = var.dns_subscription_id
}

# We need the tenant id for the key vault.
data "azurerm_client_config" "this" {}

data "azurerm_subnet" "this" {
  name                 = var.subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.dns_resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log_analytics_workspace_name
  resource_group_name = var.log_analytics_workspace_resource_group_name
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = var.location
  name     = var.resource_group_name
}

# This is the module call
module "keyvault" {
  source = "Azure/avm-res-keyvault-vault/azurerm"
  # source             = "Azure/avm-res-keyvault-vault/azurerm"
  name                          = var.key_vault_name
  enable_telemetry              = var.enable_telemetry
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.this.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = var.purge_protection_enabled
  public_network_access_enabled = var.public_network_access_enabled
  private_endpoints = {
    primary = {
      name                          = format("%s_%s", "pe", "var.key_vault_name")
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.this.id]
      subnet_resource_id            = data.azurerm_subnet.this.id
      resource_group_name           = var.virtual_network_resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "to-la"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
