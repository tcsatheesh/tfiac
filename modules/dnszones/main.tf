# Stack composition: naming engine + per-stack RG + one private DNS zone per
# entry in local.effective_zones (catalogue minus disables, union custom).
#
# Constitution IX (AVM First): the RG is provisioned via the AVM Resource Group
# module; the zones via the AVM Private DNS Zone module. No bare azurerm
# resources at this level.

module "naming" {
  source = "../naming"

  input    = local.engine_input
  services = local.engine_services
}

# Map the engine's region short code to the Azure long form. The engine's
# catalogue maps `swc => "swedencentral"`, returned via the `region` tag.
# Read it directly off any emitted name (RG is guaranteed to exist).
locals {
  region_full = module.naming.names[local.rg_canonical_name].tags.region
}

module "rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.4"

  name     = local.rg_canonical_name
  location = local.region_full
  tags     = module.naming.names[local.rg_canonical_name].tags

  enable_telemetry = false
}

module "zone" {
  for_each = local.effective_zones

  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "~> 0.5"

  domain_name = each.value.fqdn
  parent_id   = module.rg.resource_id
  tags        = local.zone_tags_by_key[each.key]

  enable_telemetry = false
}
