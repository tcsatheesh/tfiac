###############################################################################
# modules/loganalytics/main.tf
#
# AVM-backed (Constitution IX) Log Analytics Workspace + per-stack RG.
# Wraps Azure/avm-res-operationalinsights-workspace/azurerm; the wrapper
# stays thin and only enforces this repo's naming + tagging + RG conventions.
###############################################################################

locals {
  rg_canonical_name = try(var.input.purpose, null) == null ? "rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001" : "rg-${var.input.tenant}-${var.input.environment}-${var.input.purpose}-${var.region_code}-001"
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

# AVM resource module — Log Analytics Workspace.
# https://registry.terraform.io/modules/Azure/avm-res-operationalinsights-workspace/azurerm
module "workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  name                = local.ws_canonical_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.region

  log_analytics_workspace_sku               = var.sku
  log_analytics_workspace_retention_in_days = var.retention_in_days

  # Preserve current (pre-AVM) public-network behaviour. The AVM defaults
  # close these off; we keep them open here so the migration is a state
  # rename (zero infra change) instead of a network-posture flip.
  log_analytics_workspace_internet_ingestion_enabled = "true"
  log_analytics_workspace_internet_query_enabled     = "true"

  tags             = local.baseline_tags
  enable_telemetry = false
}

# State migration: keep the existing workspace in place when the wrapper
# is upgraded to AVM. AVM internally uses azurerm_log_analytics_workspace.this,
# so the address differs only by the extra module nesting.
moved {
  from = azurerm_log_analytics_workspace.this
  to   = module.workspace.azurerm_log_analytics_workspace.this
}
