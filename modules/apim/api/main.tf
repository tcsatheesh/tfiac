resource "azurerm_api_management_api" "openai" {
  name                = var.services.apim.apis.openai.name
  resource_group_name = var.services.apim.resource_group_name
  api_management_name = var.services.apim.name
  revision            = "1"
  display_name        = var.services.apim.apis.openai.display_name
  path                = var.services.apim.apis.openai.path
  protocols           = ["https"]
  import {
    content_format = "openapi-link"
    content_value  = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json"
  }
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
  service_url = "https://${var.services.open_ai.name}.openai.azure.com/openai"
}

resource "azurerm_api_management_api" "monitoring" {
  name                = var.services.apim.apis.monitoring.name
  resource_group_name = var.services.apim.resource_group_name
  api_management_name = var.services.apim.name
  revision            = "1"
  display_name        = var.services.apim.apis.monitoring.display_name
  path                = var.services.apim.apis.monitoring.path
  protocols           = ["https"]
  import {
    content_format = "openapi-link"
    content_value  = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json"
  }
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
  service_url = "https://${var.services.open_ai.name}.openai.azure.com/openai"
}

resource "azurerm_api_management_api" "ailanguage" {
  name                = var.services.apim.apis.ailanguage.name
  resource_group_name = var.services.apim.resource_group_name
  api_management_name = var.services.apim.name
  revision            = "1"
  display_name        = var.services.apim.apis.ailanguage.display_name
  path                = var.services.apim.apis.ailanguage.path
  protocols           = ["https"]
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
  service_url = "https://${var.services.ai_language.name}.cognitiveservices.azure.com/"
}

resource "azurerm_api_management_api_operation" "redactpii" {
  operation_id        = "redactpii"
  api_name            = azurerm_api_management_api.ailanguage.name
  api_management_name = var.services.apim.name
  resource_group_name = var.services.apim.resource_group_name
  display_name        = "Redact PII"
  method              = "POST"
  url_template        = "/language/:analyze-text?api-version=2022-05-01"
  description         = "Redact the PII for the given text."
}

resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = var.services.apim.name
  resource_group_name = var.services.apim.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <set-header name="x-openai-backend-id" exists-action="override">
            <value>${var.services.apim.apis.openai.backend}</value>
        </set-header>
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

resource "azurerm_api_management_api_policy" "monitoring" {
  api_name            = azurerm_api_management_api.monitoring.name
  api_management_name = var.services.apim.name
  resource_group_name = var.services.apim.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <set-header name="x-openai-backend-id" exists-action="override">
            <value>${var.services.apim.apis.monitoring.backend}</value>
        </set-header>
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

resource "azurerm_api_management_api_policy" "ailanguage" {
  api_name            = azurerm_api_management_api.ailanguage.name
  api_management_name = var.services.apim.name
  resource_group_name = var.services.apim.resource_group_name

  xml_content = <<XML
<policies>
    <!-- Throttle, authorize, validate, cache, or transform the requests -->
    <inbound>
        <authentication-managed-identity resource="https://cognitiveservices.azure.com/" />
        <base />
    </inbound>
    <!-- Control if and how the requests are forwarded to services  -->
    <backend>
        <base />
    </backend>
    <!-- Customize the responses -->
    <outbound>
        <base />
    </outbound>
    <!-- Handle exceptions and customize error responses  -->
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

