variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

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

data "azurerm_key_vault" "this" {
  name                = var.services.key_vault_name
  resource_group_name = var.services.resource_group_name
}

data "azurerm_container_registry" "this" {
  name                = var.services.container_registry_name
  resource_group_name = var.services.resource_group_name
}

data "azurerm_application_insights" "this" {
  name                = var.services.app_insights_name
  resource_group_name = var.services.resource_group_name
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
  source             = "Azure/avm-res-machinelearningservices-workspace/azurerm"
  location            = var.services.location
  name                = var.services.aml_name
  resource_group_name = var.services.resource_group_name

  storage_account = {
    resource_id = module.aml_storage.storage_account_id
    create_new  = false
  }

  key_vault = {
    resource_id = data.azurerm_key_vault.this.id
    create_new  = false
  }

  container_registry = {
    resource_id = data.azurerm_container_registry.this.id
    create_new  = false
  }

  application_insights = {
    resource_id = data.azurerm_application_insights.this.id
    create_new  = false
  }

  tags             = {}
  enable_telemetry = false
}