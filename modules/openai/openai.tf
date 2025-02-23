variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

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

data "azurerm_vnet" this {
  provider            = azurerm.vnet
  name                = var.vnet.name
  resource_group_name = var.vnet.resource_group_name
}

data "azurerm_subnet" "this" {
  provider             = azurerm.vnet
  name                 = var.services.subnet_name
  virtual_network_name = var.vnet.name
  resource_group_name  = var.vnet.resource_group_name
}

data "azurerm_private_dns_zone" "this" {
  provider            = azurerm.private_dns
  name                = var.dns.domain_names["openai"]
  resource_group_name = var.dns.resource_group_name
}

data "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.log_analytics_workspace
  name                = var.log.workspace_name
  resource_group_name = var.log.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "openai-private-dns-zone"
  private_dns_zone_name = data.azurerm_private_dns_zone.this.name
  resource_group_name   = var.vnet.resource_group_name
  virtual_network_id    = data.azurerm_vnet.this.id
}

module "openai" {
  source              = "Azure/avm-res-cognitiveservices-account/azurerm"
  kind                = "OpenAI"
  location            = var.services.open_ai_location
  name                = var.services.open_ai_name
  resource_group_name = var.services.resource_group_name
  sku_name            = "S0"
  managed_identities = {
    system_assigned = true
  }
  cognitive_deployments = {
    "gpt-4o-mini" = {
      name = "gpt-4o-mini"
      model = {
        format  = "OpenAI"
        name    = "gpt-4o-mini"
        version = "2024-07-18"
      }
      scale = {
        type  = "Standard"
        count = 100
      }
    }
  }
  network_acls = {
    default_action = "Deny"
  }
  private_endpoints = {
    pe_endpoint = {
      name                          = "pe-${var.services.open_ai_name}"
      private_dns_zone_resource_ids   = toset([data.azurerm_private_dns_zone.zone.id])
      private_service_connection_name = "psc-${var.services.open_ai_name}"
      subnet_resource_id            = data.azurerm_subnet.this.id
    }
  }
  diagnostic_settings = {
    to_la = {
      name                  = format("tola_%s", var.services.open_ai_name)
      workspace_resource_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}
