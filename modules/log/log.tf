variable "log" {}

provider "azurerm" {
  features {}
  subscription_id = var.log.subscription_id
}

# create the resource group
data "azurerm_resource_group" "avmrg" {
  name     = var.log.resource_group_name
}

# This is the module call
module "log_analytics_workspace" {
  source             = "Azure/avm-res-operationalinsights-workspace/azurerm"
  location                                  = var.log.location
  resource_group_name                       = var.log.resource_group_name
  name                                      = var.log.workspace_name
  log_analytics_workspace_retention_in_days = 30
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_identity = {
    type = "SystemAssigned"
  }
}