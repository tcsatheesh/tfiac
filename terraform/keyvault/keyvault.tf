variable "market" {
  type = string
}
variable "environment" {
  type = string
}
variable "env_type" {
  type    = string
  default = "npd"
  validation {
    condition     = var.env_type == "prd" || var.env_type == "npd"
    error_message = "env_type must be either prd or npd"
  }
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

# var.vnet_environment == "prd" ? "prd" : "npd"


locals {
  dns      = yamldecode(file("../../variables/global/prd/dns.yaml"))
  log      = yamldecode(file("../../variables/global/${var.env_type}/log.yaml"))
  vnet     = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  services = yamldecode(file("../../variables/${var.market}/${var.environment}/services.yaml"))
}

provider "azurerm" {
  features {}
  subscription_id = local.services.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = local.vnet.virtual_network_subscription_id
}

provider "azurerm" {
  features {}
  alias           = "log_analytics_workspace"
  subscription_id = local.log.log_analytics_workspace_subscription_id
}

provider "azurerm" {
  features {}
  alias           = "private_dns"
  subscription_id = local.dns.dns_subscription_id
}

# We need the tenant id for the key vault.
data "azurerm_client_config" "this" {}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = local.vnet.subnet_name
  virtual_network_name = local.vnet.virtual_network_name
  resource_group_name  = local.vnet.virtual_network_resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = local.dns.keyvault_private_dns_zone_name
  resource_group_name = local.dns.dns_resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = local.log.log_analytics_workspace_name
  resource_group_name = local.log.log_analytics_workspace_resource_group_name
}

# This is the module call
module "keyvault" {
  source = "Azure/avm-res-keyvault-vault/azurerm"
  # source             = "Azure/avm-res-keyvault-vault/azurerm"
  name                          = local.services.key_vault_name
  enable_telemetry              = local.services.enable_telemetry
  location                      = local.services.location
  resource_group_name           = local.services.resource_group_name
  tenant_id                     = data.azurerm_client_config.this.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = local.services.purge_protection_enabled
  public_network_access_enabled = local.services.public_network_access_enabled
  private_endpoints = {
    primary = {
      name                          = format("%s_%s", "pe", local.services.key_vault_name)
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.this.id]
      subnet_resource_id            = data.azurerm_subnet.this.id
      resource_group_name           = local.vnet.virtual_network_resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = "to-la"
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
