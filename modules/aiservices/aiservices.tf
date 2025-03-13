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
  subscription_id = var.services.subscription_id
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
  for_each            = local.endpoints
  provider            = azurerm.private_dns
  name                = var.dns.domain_names[each.value]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  for_each              = local.endpoints
  provider              = azurerm.private_dns
  name                  = "${each.key}-${var.vnet.name}"
  private_dns_zone_name = var.dns.domain_names[each.key]
  resource_group_name   = var.dns.resource_group_name
  virtual_network_id    = data.azurerm_virtual_network.this.id
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
