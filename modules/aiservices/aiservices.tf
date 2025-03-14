variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

locals {
  endpoints = toset(["aiservices", "cognitiveservices", "openai"])
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

data "azurerm_virtual_network" "this" {
  provider            = azurerm.vnet
  name                = var.vnet.name
  resource_group_name = var.vnet.resource_group_name
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.vnet.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  for_each            = local.endpoints
  provider            = azurerm.dns
  name                = var.dns.domain_names[each.value]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "aiservices" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "AIServices"
  location            = var.services.ai_services.location
  name                = var.services.ai_services.name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S0"
  managed_identities = {
    system_assigned = true
  }
  network_acls = {
    default_action = "Deny"
  }
  public_network_access_enabled = false
  custom_subdomain_name         = var.services.ai_services.name
  private_endpoints = {
    for endpoint in local.endpoints :
    endpoint => {
      name                            = "pe-${endpoint}-${var.services.ai_services.name}"
      private_dns_zone_resource_ids   = toset([data.azurerm_private_dns_zone.this[endpoint].id])
      private_service_connection_name = "psc-${endpoint}-${var.services.ai_services.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${endpoint}-${var.services.ai_services.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = format("tola_%s", var.services.ai_services.name)
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
