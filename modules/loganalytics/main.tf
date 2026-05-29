# T008/T009/T026 - stack composition: naming engine + AVM RG + AVM workspace.
#
# Constitution VI: NO provider blocks here (declared in providers.tf only as
# required_providers passthrough).
# Constitution IX: every Azure resource flows through AVM modules - no bare
# azurerm_* resources.

module "naming" {
  source = "../naming"

  input    = var.input
  services = local.engine_services
}

module "rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.4"

  name     = local.rg_canonical_name
  location = local.region_full
  tags     = module.naming.names[local.rg_canonical_name].tags

  enable_telemetry = false
}

module "workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.5"

  name                = local.workspace_canonical_name
  location            = local.region_full
  resource_group_name = module.rg.name
  tags                = module.naming.names[local.workspace_canonical_name].tags

  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = var.retention_in_days
  log_analytics_workspace_daily_quota_gb    = var.daily_quota_gb

  enable_telemetry = false
}
