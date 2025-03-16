module "apim_public_ip" {
  source              = "Azure/avm-res-network-publicipaddress/azurerm"
  name                = var.services.apim.public_ip.name
  location            = var.services.apim.public_ip.location
  resource_group_name = var.services.apim.public_ip.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.services.apim.public_ip.domain_name_label

}

resource "azurerm_api_management" "this" {
  name                = var.services.apim.name
  location            = var.services.apim.location
  resource_group_name = var.services.apim.resource_group_name
  publisher_name      = var.services.apim.publisher_name
  publisher_email     = var.services.apim.publisher_email

  sku_name = var.services.apim.sku.name

  identity {
    type = "SystemAssigned"
  }

  virtual_network_type = var.services.apim.virtual_network_type
  virtual_network_configuration {
    subnet_id = data.azurerm_subnet.this.id
  }
  public_ip_address_id = module.apim_public_ip.public_ip_id
}

resource "azurerm_api_management_logger" "this" {
  name                = "apimlogger"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.services.apim.resource_group_name

  application_insights {
    instrumentation_key = var.appinsights_instrumentation_key
  }
}

resource "azurerm_api_management_diagnostic" "this" {
  identifier               = "applicationinsights"
  resource_group_name      = var.services.apim.resource_group_name
  api_management_name      = azurerm_api_management.this.name
  api_management_logger_id = azurerm_api_management_logger.this.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = var.services.apim.diagnostics.frontend.request.body_bytes
    headers_to_log = var.services.apim.diagnostics.frontend.request.headers_to_log
  }

  frontend_response {
    body_bytes     = var.services.apim.diagnostics.frontend.response.body_bytes
    headers_to_log = var.services.apim.diagnostics.frontend.response.headers_to_log
  }

  backend_request {
    body_bytes     = var.services.apim.diagnostics.backend.request.body_bytes
    headers_to_log = var.services.apim.diagnostics.backend.request.headers_to_log
  }

  backend_response {
    body_bytes     = var.services.apim.diagnostics.backend.response.body_bytes
    headers_to_log = var.services.apim.diagnostics.backend.response.headers_to_log
  }
}