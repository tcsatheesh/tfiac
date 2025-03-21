locals {
  dns         = yamldecode(file("../../variables/grp/prd/dns.yaml"))
  log         = yamldecode(file("../../variables/grp/${var.env_type}/log.yaml"))
  firewall    = yamldecode(file("../../variables/grp/${var.env_type}/firewall.yaml"))
  vnet        = yamldecode(file("../../variables/${var.market}/${var.env_type}/vnet.yaml"))
  remote_vnet = yamldecode(file("../../variables/grp/${var.env_type}/vnet.yaml"))
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
  subscription_id = local.vnet.subscription_id
}

provider "azurerm" {
  features {}
  alias           = "remote_vnet"
  subscription_id = local.remote_vnet.subscription_id
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

module "vnet" {
  source      = "../../modules/vnet"
  dns         = local.dns
  log         = local.log
  vnet        = local.vnet
  firewall    = local.firewall
  remote_vnet = local.remote_vnet
  providers = {
    azurerm.vnet        = azurerm
    azurerm.log         = azurerm.log
    azurerm.dns         = azurerm.dns
    azurerm.remote_vnet = azurerm.remote_vnet
  }
}



