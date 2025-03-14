variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

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
  name                 = var.services.subnet.name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.dns
  name                = var.dns.domain_names["openai"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

module "openai" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "OpenAI"
  location            = var.services.open_ai.location
  name                = var.services.open_ai.name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S0"
  managed_identities = {
    system_assigned = true
  }
  cognitive_deployments = var.services.open_ai.deployments
  network_acls = {
    default_action = "Deny"
  }
  public_network_access_enabled = false
  private_endpoints = {
    pe_endpoint = {
      name                            = "pe-${var.services.open_ai.name}"
      private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.this.id]
      private_service_connection_name = "psc-${var.services.open_ai.name}"
      subnet_resource_id              = data.azurerm_subnet.this.id
      network_interface_name          = "nic-pe-${var.services.open_ai.name}"
      resource_group_name             = var.vnet.resource_group_name
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = format("tola_%s", var.services.open_ai.name)
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
