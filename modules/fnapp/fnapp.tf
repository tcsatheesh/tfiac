variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}
variable "app_insights_instrumentation_key" {
  description = "The instrumentation key of the application insights"
  type        = string

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
  name                 = var.services.function_app_subnet_name
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

resource "azurerm_service_plan" "this" {
  location            = var.services.location
  name                = var.services.function_app_service_plan_name
  os_type             = "Linux"
  resource_group_name = var.services.resource_group_name
  sku_name            = "EP1"

}

module "function_app_storage" {
  source       = "../../modules/storage"
  dns          = var.dns
  log          = var.log
  vnet         = var.vnet
  services     = var.services
  storage_type = "function_app"
}

resource "azurerm_function_app" "fnapp" {
  name                       = var.services.function_app_name
  location                   = var.services.location
  resource_group_name        = var.services.resource_group_name
  app_service_plan_id        = azurerm_service_plan.this.id
  storage_account_name       = module.function_app_storage.storage_account_name
  storage_account_access_key = module.function_app_storage.storage_account_access_key
  version                    = var.services.runtime_version
  count                      = 1

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION         = var.services.function_app.runtime_version
    FUNCTIONS_WORKER_RUNTIME            = var.services.function_app.worker_runtime
    DOCKER_REGISTRY_SERVER_URL          = var.services.function_app.docker_registry_server_url
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    DOCKER_REGISTRY_SERVER_USERNAME     = var.services.function_app.docker_registry_server_username
    APPINSIGHTS_INSTRUMENTATIONKEY      = var.app_insights_instrumentation_key
  }
  site_config {
    linux_fx_version = var.services.function_app.app_linux_fx_versions
    always_on        = true
  }

  identity {
    type = "SystemAssigned"
  }
}
