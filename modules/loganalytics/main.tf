###############################################################################
# modules/loganalytics/main.tf
#
# Engine-driven Log Analytics Workspace + per-stack resource group.
# Provider-less (Constitution VI); inherits azurerm from the root stack.
###############################################################################

locals {
  rg_canonical_name = "rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
  ws_canonical_name = "log-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"

  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_canonical_name
  location = var.region
  tags     = try(var.naming[local.rg_canonical_name].tags, local.baseline_tags)
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.ws_canonical_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.region
  sku                 = var.sku
  retention_in_days   = var.retention_in_days
  tags                = local.baseline_tags
}
