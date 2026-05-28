###############################################################################
# terraform/dns/main.tf  (feature 002 — replaces legacy module "dns" wiring)
#
# Composes module.naming (feature 001) + module.dnszones (feature 002 thin
# module). The naming engine produces the per-stack RG name + a sized batch
# of pdns-NNN instance names (engine-emitted, used for audit only — the
# Azure resource name on each zone is the FQDN itself per FR-005/FR-007).
###############################################################################

module "naming" {
  source = "../../modules/naming"

  input = local.input
}

# T038 — client_config for the subscription_pinned check in validate.tf.
data "azurerm_client_config" "current" {}

module "dnszones" {
  source = "../../modules/dnszones"

  naming      = module.naming.names
  region      = var.region
  region_code = lookup(local.region_codes, var.region) # static map; engine does not expose region_codes

  custom_zones            = var.custom_zones
  disable_catalogue_zones = var.disable_catalogue_zones

  input = local.input
}
