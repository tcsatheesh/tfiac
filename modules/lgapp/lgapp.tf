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
  name                 = var.services.logic_app.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["website"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

resource "azurerm_service_plan" "this" {
  location            = var.services.location
  name                = var.services.logic_app.service_plan_name
  os_type             = "Windows"
  resource_group_name = var.services.resource_group_name
  sku_name            = "WS1"
}

module "logic_app_storage" {
  source                        = "../../modules/storage"
  dns                           = var.dns
  log                           = var.log
  vnet                          = var.vnet
  services                      = var.services
  storage_type                  = "logic_app"
  public_network_access_enabled = true
  shared_access_key_enabled     = true
  network_rules = {
    default_action = "Allow"
  }
  providers = {
    azurerm.services = azurerm.services
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
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
  public_network_access      = "Disabled"
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
