variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}
variable "app_insights_id" {
  description = "The resource id of the application insights"
  type        = string
}
variable "keyvault_id" {
  description = "The resource id of the key vault"
  type        = string
}
variable "container_registry_id" {
  description = "The resource id of the container registry"
  type        = string
}


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
  name                 = var.services.vnet.subnet.name
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

module "aml_storage" {
  source               = "../../modules/storage"
  dns                  = var.dns
  log                  = var.log
  vnet                 = var.vnet
  services             = var.services
  storage_account_name = var.services.aml.storage_account_name
  providers = {
    azurerm.services = azurerm.services
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "azureml" {
  source              = "Azure/avm-res-machinelearningservices-workspace/azurerm"
  location            = var.services.location
  name                = var.services.aml.name
  resource_group_name = var.services.resource_group_name

  storage_account = {
    resource_id = module.aml_storage.storage_account_id
    create_new  = false
  }

  key_vault = {
    resource_id = var.keyvault_id
    create_new  = false
  }

  container_registry = {
    resource_id = var.container_registry_id
    create_new  = false
  }

  application_insights = {
    resource_id = var.app_insights_id
    create_new  = false
  }

  tags             = {}
  enable_telemetry = false
}
