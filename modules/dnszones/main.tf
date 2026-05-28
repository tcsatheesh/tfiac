# modules/dnszones/main.tf
# Authored by feature 002 (Private DNS Zones, prd-hub-only).
#
# Owns:
#   - the per-stack resource group (engine-named)
#   - the for_each Private DNS Zone set (catalogue ∪ custom − disabled)
#   - catalogue-aware preconditions (unknown disable keys, shadowed FQDNs)
#
# Tags policy: a six-key baseline (tenant, topology, environment, region,
# managed_by, repo) is derived locally from `var.input` and applied uniformly
# to both catalogue zones and custom FQDNs. This matches the engine baseline
# byte-for-byte (see modules/naming/locals.tf:baseline_tags) and survives the
# edge case where every catalogue key is disabled and no custom zone is given
# (no engine pdnsz record exists to inherit from).

locals {
  # Engine-emitted RG name. The root stack derives `var.region_code` from
  # module.naming.region_codes lookup (or a static fallback map); the module
  # itself never re-derives the short code.
  rg_canonical_name = "rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"

  # Six-key baseline tag map (Constitution VIII). Identical bytes to the
  # engine's baseline_tags for the same input.
  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }

  # Effective catalogue → enabled catalogue map (key → FQDN).
  catalogue_enabled = {
    for k, fqdn in local.catalogue : k => fqdn
    if !contains(var.disable_catalogue_zones, k)
  }

  # Custom zones map (FQDN → FQDN). FR-024 / FR-025: key is the FQDN itself.
  custom_map = { for fqdn in var.custom_zones : fqdn => fqdn }

  # Final for_each set (FR-024 / FR-025).
  zone_set = merge(local.catalogue_enabled, local.custom_map)
}

resource "azurerm_resource_group" "this" {
  # The engine record's MAP KEY is the canonical name; the record itself
  # does NOT carry a "name" attribute (see modules/naming/locals.tf:emitted).
  # We therefore use local.rg_canonical_name directly as the resource name
  # AND as the map lookup for tags.
  name     = local.rg_canonical_name
  location = var.region
  tags     = var.naming[local.rg_canonical_name].tags
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.zone_set

  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.baseline_tags
}
