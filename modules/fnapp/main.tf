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
  storage_account_name          = var.services.function_app.storage_account_name
  public_network_access_enabled = true
  shared_access_key_enabled     = false

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
    WEBSITES_ENABLE_APP_SERVICE_STORAGE      = false
    WEBSITE_VNET_ROUTE_ALL                   = "1"
    WEBSITE_CONTENTOVERVNET                  = "1"
    FUNCTIONS_WORKER_RUNTIME                 = "python"
    PYTHONDONTWRITEBYTECODE                  = "1"
    WEBSITE_CONTENTSHARE                     = var.services.function_app.name
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = module.function_app_storage.storage_connection_string

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
