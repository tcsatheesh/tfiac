locals {
  dns      = yamldecode(file("../../variables/global/prd/dns.yaml"))
  log      = yamldecode(file("../../variables/global/${var.env_type}/log.yaml"))
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
  subscription_id = local.services.subscription_id
}

module "keyvault" {
  source   = "../../modules/keyvault"
  dns      = local.dns
  log      = local.log
  vnet     = local.vnet
  services = local.services
}

module "appinsights" {
  source   = "../../modules/appinsights"
  dns      = local.dns
  log      = local.log
  vnet     = local.vnet
  services = local.services
}

module "landing_zone" {
  source       = "../../modules/storage"
  dns          = local.dns
  log          = local.log
  vnet         = local.vnet
  services     = local.services
  storage_type = "landing"
}

module "openai" {
  source   = "../../modules/openai"
  dns      = local.dns
  log      = local.log
  vnet     = local.vnet
  services = local.services
}

module "aiservices" {
  source   = "../../modules/aiservices"
  dns      = local.dns
  log      = local.log
  vnet     = local.vnet
  services = local.services
}
