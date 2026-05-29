###############################################################################
# modules/dnszones/main.tf
#
# AVM-backed (Constitution IX) Private DNS Zones + per-stack RG.
# Wraps Azure/avm-res-network-privatednszone/azurerm (one module call per
# zone via for_each); the wrapper enforces this repo's RG-naming, tagging,
# and catalogue-vs-custom merge semantics.
###############################################################################

locals {
  # Engine-emitted RG name. Mirrors modules/naming locals.rg_canonical with
  # the optional purpose segment.
  rg_canonical_name = (
    try(var.input.purpose, null) == null
    ? "rg-${var.input.tenant}-${var.input.environment}-${var.region_code}-001"
    : "rg-${var.input.tenant}-${var.input.environment}-${var.input.purpose}-${var.region_code}-001"
  )

  # Six-key baseline tag map (Constitution VIII).
  baseline_tags = {
    tenant      = var.input.tenant
    topology    = var.input.topology
    environment = var.input.environment
    region      = var.input.region
    managed_by  = "terraform"
    repo        = var.input.repo
  }

  # Effective catalogue map (key → FQDN), after disables.
  catalogue_enabled = {
    for k, fqdn in local.catalogue : k => fqdn
    if !contains(var.disable_catalogue_zones, k)
  }

  # Custom zones map (FQDN → FQDN).
  custom_map = { for fqdn in var.custom_zones : fqdn => fqdn }

  # Final for_each set: catalogue ∪ custom.
  zone_set = merge(local.catalogue_enabled, local.custom_map)
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_canonical_name
  location = var.region
  tags     = var.naming[local.rg_canonical_name].tags

  lifecycle {
    precondition {
      # Fail fast if the engine's `naming.names` map does not contain a record
      # keyed by the canonical name we just string-built. Catches drift
      # between this module's rg_canonical_name expression and the engine's
      # actual rg-naming output (e.g. if the engine changes its rg shape
      # without this module being updated).
      condition = contains(keys(var.naming), local.rg_canonical_name)
      error_message = format(
        "engine drift: var.naming has no record keyed %q. The dnszones module re-derives the RG canonical to look up tags; if the engine's RG-naming shape changes, this module must be updated in lock-step. Available naming keys: %v.",
        local.rg_canonical_name,
        sort(keys(var.naming)),
      )
    }
  }
}

# AVM resource module — Private DNS Zone. One call per zone.
# https://registry.terraform.io/modules/Azure/avm-res-network-privatednszone/azurerm
module "zone" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.5.0"

  for_each = local.zone_set

  domain_name = each.value
  parent_id   = azurerm_resource_group.this.id

  tags             = local.baseline_tags
  enable_telemetry = false
}
