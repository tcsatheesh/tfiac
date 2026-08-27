# C-018 (Amendment 2026-05-31) — VNet + hub-DNS remote-state lookups.
# Broadened by C-020/C-021 (Amendment 2026-06-01) to also serve the ACR private
# endpoint (FR-029) and the internal Container Apps environment (FR-030).
#
# Consulted whenever ANY private-network feature is requested: the ACR PE
# (var.enable_container_registry_private_endpoint), the storage/search/keyvault
# private endpoints, a Cosmos DB selection, or a Container Apps internal
# environment (var.enable_container_apps). The remote-state data sources are
# count-gated so that the default (everything disabled) path reads NEITHER
# backend — keeping day-one plans free of any vnet/dns dependency. The
# variable-level validation on var.dns_state_backend / var.vnet_state_backend
# already guarantees both backends are non-null whenever any of these features
# is enabled, so the try(...) guards here only exist to keep expressions
# evaluable at count = 0.

locals {
  # FR-041 (C-048) — private-by-default resolution. Each per-service PE toggle
  # is optional (null = inherit); coalesce(<explicit>, var.private_by_default)
  # lets an explicit true/false win while null inherits the master switch. Each
  # is gated on the relevant service type being SELECTED so that turning on the
  # master for a stack that selects no PE-capable service neither reads a remote
  # state nor demands the backends (C-049 — backends are only required when a
  # PE-capable service is actually selected).
  acr_pe_required       = local.registry_selected && coalesce(var.enable_container_registry_private_endpoint, var.private_by_default)
  storage_pe_required   = local.storage_selected && coalesce(var.enable_storage_private_endpoint, var.private_by_default)
  search_pe_required    = local.search_selected && coalesce(var.enable_search_private_endpoint, var.private_by_default)
  keyvault_pe_required  = local.keyvault_selected && coalesce(var.enable_keyvault_private_endpoint, var.private_by_default)
  container_apps_active = var.enable_container_apps

  # FR-032 (Amendment 2026-06-02) — Cosmos DB is private-ONLY: selecting it
  # ALWAYS requires the spoke VNet (PE subnet) + hub DNS (cosmos-sql zone)
  # remote states. There is no toggle — selection implies private wiring.
  cosmosdb_selected = length([for s in var.services : s if s.type == "cosmosdb"]) > 0

  # FR-052 (Amendment 2026-08-27) — Azure SQL server and Data Factory are
  # private-ONLY (like cosmosdb): selecting either ALWAYS requires the spoke
  # VNet (PE subnet) + hub DNS remote states. No toggle.
  sql_selected         = length([for s in var.services : s if s.type == "sql_server"]) > 0
  datafactory_selected = length([for s in var.services : s if s.type == "data_factory"]) > 0

  # Any feature that needs the spoke VNet remote state.
  vnet_state_required = local.acr_pe_required || local.storage_pe_required || local.search_pe_required || local.keyvault_pe_required || local.container_apps_active || ((local.cosmosdb_selected || local.sql_selected || local.datafactory_selected) && var.vnet_state_backend != null)
  # Any feature that needs the hub DNS remote state (PE zone ids).
  dns_state_required = local.acr_pe_required || local.storage_pe_required || local.search_pe_required || local.keyvault_pe_required || ((local.cosmosdb_selected || local.sql_selected || local.datafactory_selected) && var.dns_state_backend != null)
}

data "terraform_remote_state" "vnet" {
  count   = local.vnet_state_required ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = try(var.vnet_state_backend.resource_group_name, "")
    storage_account_name = try(var.vnet_state_backend.storage_account_name, "")
    container_name       = try(var.vnet_state_backend.container_name, "")
    key                  = try(var.vnet_state_backend.key, "")
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}

data "terraform_remote_state" "dns" {
  count   = local.dns_state_required ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = try(var.dns_state_backend.resource_group_name, "")
    storage_account_name = try(var.dns_state_backend.storage_account_name, "")
    container_name       = try(var.dns_state_backend.container_name, "")
    key                  = try(var.dns_state_backend.key, "")
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}

locals {
  # C-020 (FR-029) — ACR PE: same spoke subnet (by role) + the hub acr zone.
  acr_pe_subnet_id = local.acr_pe_required ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  acr_pe_zone_ids = local.acr_pe_required ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["acr"]
  ] : []

  # C-035 (FR-034) — storage PE: same spoke subnet (by role) + the hub blob zone
  # (privatelink.blob.core.windows.net). null/empty when storage PE disabled.
  storage_pe_subnet_id = local.storage_pe_required ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  storage_pe_zone_ids = local.storage_pe_required ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["blob"]
  ] : []

  # C-039 (FR-035) — search PE: same spoke subnet (by role) + the hub search
  # zone (privatelink.search.windows.net). null/empty when search PE disabled.
  search_pe_subnet_id = local.search_pe_required ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  search_pe_zone_ids = local.search_pe_required ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["search"]
  ] : []

  # C-050 (FR-041) — Key Vault PE: same spoke subnet (by role) + the hub vault
  # zone (privatelink.vaultcore.azure.net). null/empty when KV PE disabled.
  keyvault_pe_subnet_id = local.keyvault_pe_required ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  keyvault_pe_zone_ids = local.keyvault_pe_required ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["vault"]
  ] : []

  # C-021 (FR-030) — Container Apps internal env: delegated subnet (by role) +
  # the spoke VNet id for the private default-domain DNS zone link.
  container_apps_subnet_id = local.container_apps_active ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.container_apps_subnet_role].id,
    null,
  ) : null

  spoke_vnet_id = local.container_apps_active ? try(
    data.terraform_remote_state.vnet[0].outputs.vnet_id,
    null,
  ) : null

  # FR-032 — Cosmos DB PE: the spoke PE subnet (by role) + the hub cosmos-sql
  # zone (privatelink.documents.azure.com). null/empty when no cosmosdb selected.
  cosmosdb_pe_subnet_id = local.cosmosdb_selected ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  cosmosdb_pe_zone_ids = local.cosmosdb_selected ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["cosmos-sql"]
  ] : []

  # FR-052 — Azure SQL PE: spoke PE subnet (by role) + hub sql zone
  # (privatelink.database.windows.net).
  sql_pe_subnet_id = local.sql_selected ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  sql_pe_zone_ids = local.sql_selected ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["sql"]
  ] : []

  # FR-052 — Data Factory inbound PE: spoke PE subnet (by role) + the hub
  # datafactory (dataFactory sub-resource) and adf (portal sub-resource) zones.
  datafactory_pe_subnet_id = local.datafactory_selected ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  datafactory_pe_zone_ids = local.datafactory_selected ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["datafactory"]
  ] : []

  datafactory_portal_zone_ids = local.datafactory_selected ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["adf"]
  ] : []
}
