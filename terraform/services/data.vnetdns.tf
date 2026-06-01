# C-018 (Amendment 2026-05-31) — VNet + hub-DNS remote-state lookups (FR-027).
# Broadened by C-020/C-021 (Amendment 2026-06-01) to also serve the ACR private
# endpoint (FR-029) and the internal Container Apps environment (FR-030).
#
# Consulted whenever ANY private-network feature is requested: the Foundry PE
# (var.enable_aifoundry_private_endpoint), the ACR PE
# (var.enable_container_registry_private_endpoint), or a Container Apps internal
# environment (var.enable_container_apps). The remote-state data sources are
# count-gated so that the default (everything disabled) path reads NEITHER
# backend — keeping day-one plans free of any vnet/dns dependency. The
# variable-level validation on var.dns_state_backend / var.vnet_state_backend
# already guarantees both backends are non-null whenever any of these features
# is enabled, so the try(...) guards here only exist to keep expressions
# evaluable at count = 0.

locals {
  aifoundry_pe_required = var.enable_aifoundry_private_endpoint
  acr_pe_required       = var.enable_container_registry_private_endpoint
  container_apps_active = var.enable_container_apps

  # Any feature that needs the spoke VNet remote state.
  vnet_state_required = local.aifoundry_pe_required || local.acr_pe_required || local.container_apps_active
  # Any feature that needs the hub DNS remote state (PE zone ids).
  dns_state_required = local.aifoundry_pe_required || local.acr_pe_required
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
  # Subnet id for the configured Foundry PE role (null when PE disabled). The
  # vnet stack `subnets` output is map(role => { id, name, address_prefix }).
  pe_subnet_id = local.aifoundry_pe_required ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  # Hub private DNS zone IDs the AIServices account PE registers into:
  # cogsvc + openai + aiservices (the latter added by C-018 to the DNS
  # catalogue). Empty list when PE disabled.
  pe_zone_ids = local.aifoundry_pe_required ? [
    for z in ["cogsvc", "openai", "aiservices"] :
    data.terraform_remote_state.dns[0].outputs.zone_ids[z]
  ] : []

  # C-020 (FR-029) — ACR PE: same spoke subnet (by role) + the hub acr zone.
  acr_pe_subnet_id = local.acr_pe_required ? try(
    data.terraform_remote_state.vnet[0].outputs.subnets[var.private_endpoint_subnet_role].id,
    null,
  ) : null

  acr_pe_zone_ids = local.acr_pe_required ? [
    data.terraform_remote_state.dns[0].outputs.zone_ids["acr"]
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
}
