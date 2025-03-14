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
  name                 = var.services.function_app.subnet_name
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
  name                = var.services.function_app.service_plan_name
  os_type             = "Linux"
  resource_group_name = var.services.resource_group_name
  sku_name            = "EP1"
}

module "function_app_storage" {
  source                        = "../../modules/storage"
  dns                           = var.dns
  log                           = var.log
  vnet                          = var.vnet
  services                      = var.services
  storage_type                  = "function_app"
  public_network_access_enabled = true # TODO: fix later
  shared_access_key_enabled     = true # TODO: fix later

  providers = {
    azurerm.services = azurerm.services
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

resource "azurerm_linux_function_app" "fnapp" {
  name                          = var.services.function_app.name
  location                      = var.services.location
  resource_group_name           = var.services.resource_group_name
  service_plan_id               = azurerm_service_plan.this.id
  storage_account_name          = module.function_app_storage.storage_account_name
  storage_uses_managed_identity = true
  https_only                    = true
  public_network_access_enabled = false
  functions_extension_version   = "~4"
  vnet_image_pull_enabled       = true
  virtual_network_subnet_id     = data.azurerm_subnet.this.id
  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    WEBSITE_VNET_ROUTE_ALL              = "1"
    WEBSITE_CONTENTOVERVNET             = "1"
  }
  site_config {
    always_on                               = true
    application_insights_key                = var.app_insights_instrumentation_key
    application_insights_connection_string  = var.app_insights_connection_string
    container_registry_use_managed_identity = true
    minimum_tls_version                     = "1.2"
    vnet_route_all_enabled                  = true
    application_stack {
      docker {
        registry_url = var.services.function_app.docker.registry_server_url
        image_name   = var.services.function_app.docker.image_name
        image_tag    = var.services.function_app.docker.image_tag
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }
}
