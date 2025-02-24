variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}
variable "app_insights_instrumentation_key" {
  description = "The instrumentation key of the application insights"
  type        = string
}
variable "app_insights_connection_string" {
  description = "The connection string of the application insights"
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
  name                 = var.services.logic_app.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = var.dns.domain_names["website"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

resource "azurerm_service_plan" "this" {
  location            = var.services.location
  name                = var.services.function_app.service_plan_name
  os_type             = "Windows"
  resource_group_name = var.services.resource_group_name
  sku_name            = "WS1"
}

module "logic_app_storage" {
  source       = "../../modules/storage"
  dns          = var.dns
  log          = var.log
  vnet         = var.vnet
  services     = var.services
  storage_type = "logic_app"
}

resource "azurerm_logic_app_standard" "this" {
  name                       = var.services.logic_app.name
  location                   = var.services.location
  resource_group_name        = var.services.resource_group_name
  app_service_plan_id        = azurerm_service_plan.this.id
  storage_account_name       = module.logic_app_storage.storage_account_name
  storage_account_access_key = module.logic_app_storage.storage_account_key
  https_only                 = true
  virtual_network_subnet_id  = data.azurerm_subnet.this.id
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "dotnet"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~14"
  }
  site_config {
    always_on              = true
    min_tls_version        = "1.2"
    vnet_route_all_enabled = true
  }
  identity {
    type = "SystemAssigned"
  }
}
