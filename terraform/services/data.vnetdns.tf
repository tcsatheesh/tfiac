# C-018 (Amendment 2026-05-31) — VNet + hub-DNS remote-state lookups (FR-027).
#
# Only consulted when var.enable_aifoundry_private_endpoint = true. The
# remote-state data sources are count-gated so that the default (PE disabled)
# path reads NEITHER backend — keeping day-one plans free of any vnet/dns
# dependency. The variable-level validation on var.dns_state_backend already
# guarantees both backends are non-null whenever the feature is enabled, so the
# try(...) guards here only exist to keep expressions evaluable at count = 0.

locals {
  aifoundry_pe_required = var.enable_aifoundry_private_endpoint
}

data "terraform_remote_state" "vnet" {
  count   = local.aifoundry_pe_required ? 1 : 0
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
  count   = local.aifoundry_pe_required ? 1 : 0
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
  # Subnet id for the configured role (null when PE disabled). The vnet stack
  # `subnets` output is map(role => { id, name, address_prefix }).
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
}
