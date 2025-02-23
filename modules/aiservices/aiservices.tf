variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}


locals {
  endpoints = toset(["aiservices", "cognitiveservices", "openai"])
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
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
  for_each = local.endpoints
  provider            = azurerm.private_dns
  name                = var.dns.domain_names[each.value]
  resource_group_name = var.dns.resource_group_name
}


data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "aiservices" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "AIServices"
  location            = var.services.ai_services_location
  name                = var.services.ai_services_name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S0"
  managed_identities = {
    system_assigned = true
  }
  private_endpoints = {
    for endpoint in local.endpoints :
    endpoint => {
      name                          = "pe-${endpoint}-${var.services.ai_services_name}"
      subnet_resource_id            = data.azurerm_subnet.this.id
      subresource_name              = "account"
      private_dns_zone_resource_ids = [data.azurerm_private_dns_zone.this.id]
      # these are optional but illustrate making well-aligned service connection & NIC names.
      private_service_connection_name = "psc-${endpoint}-${var.services.ai_services_name}"
      network_interface_name          = "nic-pe-${endpoint}-${var.services.ai_services_name}"
      inherit_lock                    = false
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = format("tola_%s", var.services.ai_services_name)
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
