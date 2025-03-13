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


provider "azurerm" {
  features {}
  subscription_id = var.services.subscription_id
}

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
  name                 = var.services.subnet.name
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

module "aml_storage" {
  source       = "../../modules/storage"
  dns          = var.dns
  log          = var.log
  vnet         = var.vnet
  services     = var.services
  storage_type = "aml"
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
