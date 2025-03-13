locals {
  dns      = yamldecode(file("../../variables/grp/prd/dns.yaml"))
  log      = yamldecode(file("../../variables/grp/${var.env_type}/log.yaml"))
  vnet     = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  services = yamldecode(file("../../variables/${var.market}/${var.environment}/services.yaml"))
}

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 5.0.0"
    }
  }
  backend "azurerm" {
    subscription_id      = "<DUMMY>"
    resource_group_name  = "<DUMMY>"
    storage_account_name = "<DUMMY>"
    container_name       = "<DUMMY>"
    key                  = "<DUMMY>"
    use_azuread_auth     = true
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
  subscription_id     = local.services.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "vnet"
  subscription_id = local.vnet.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "log"
  subscription_id = local.log.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "dns"
  subscription_id = local.dns.subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = local.services.resource_group_name
  location = local.services.location
}

module "keyvault" {
  source     = "../../modules/keyvault"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "appinsights" {
  source     = "../../modules/appinsights"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "landing_zone" {
  source       = "../../modules/storage"
  dns          = local.dns
  log          = local.log
  vnet         = local.vnet
  services     = local.services
  storage_type = "landing"
  depends_on   = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "aiservices" {
  source     = "../../modules/aiservices"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "openai" {
  source     = "../../modules/openai"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "docint" {
  source     = "../../modules/docint"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "language" {
  source     = "../../modules/language"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "cntreg" {
  source     = "../../modules/cntreg"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "aml" {
  source                = "../../modules/aml"
  dns                   = local.dns
  log                   = local.log
  vnet                  = local.vnet
  services              = local.services
  app_insights_id       = module.appinsights.app_insights_id
  keyvault_id           = module.keyvault.keyvault_id
  container_registry_id = module.cntreg.container_registry_id
  depends_on            = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "function_app" {
  source                           = "../../modules/fnapp"
  dns                              = local.dns
  log                              = local.log
  vnet                             = local.vnet
  services                         = local.services
  app_insights_instrumentation_key = module.appinsights.instrumentation_key
  app_insights_connection_string   = module.appinsights.connection_string
  depends_on                       = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "search" {
  source     = "../../modules/search"
  dns        = local.dns
  log        = local.log
  vnet       = local.vnet
  services   = local.services
  depends_on = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}

module "logic_app" {
  source                           = "../../modules/lgapp"
  dns                              = local.dns
  log                              = local.log
  vnet                             = local.vnet
  services                         = local.services
  app_insights_instrumentation_key = module.appinsights.instrumentation_key
  app_insights_connection_string   = module.appinsights.connection_string
  depends_on                       = [azurerm_resource_group.rg]
  providers = {
    azurerm.services = azurerm
    azurerm.vnet     = azurerm.vnet
    azurerm.log      = azurerm.log
    azurerm.dns      = azurerm.dns
  }
}
