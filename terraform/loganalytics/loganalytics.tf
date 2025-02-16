variable log_analytics_workspace_name {
  type = string
}
variable "location" {
  type = string
  
}
variable "log_analytics_workspace_resource_group_name" {
  type = string
  
}
variable "log_analytics_workspace_subscription_id" {
  type = string
  
}
variable "enable_telemetry" {
  type    = bool
  default = true
  
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.log_analytics_workspace_subscription_id
}

# This is required for resource modules
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = var.log_analytics_workspace_resource_group_name
}

# This is the module call
module "log_analytics_workspace" {
  source             = "Azure/avm-res-operationalinsights-workspace/azurerm"
  enable_telemetry                          = var.enable_telemetry
  location                                  = azurerm_resource_group.rg.location
  resource_group_name                       = azurerm_resource_group.rg.name
  name                                      = var.log_analytics_workspace_name
  log_analytics_workspace_retention_in_days = 30
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_identity = {
    type = "SystemAssigned"
  }
}