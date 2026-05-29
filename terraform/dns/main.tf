# Root stack: invoke the dnszones wrapper module and assert subscription parity.
#
# FR-029 / DNS-INV-8: var.subscription_id MUST match the active provider's
# subscription. The `check` block fires at plan time so an operator targeting
# the wrong subscription gets a clear error long before any apply touches Azure.

data "azurerm_client_config" "current" {}

check "subscription_match" {
  assert {
    condition     = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = "FR-029 / DNS-INV-8: var.subscription_id (${var.subscription_id}) does not match the active azurerm provider subscription (${data.azurerm_client_config.current.subscription_id}). Re-run `az account set --subscription <id>` and re-plan."
  }
}

module "dnszones" {
  source = "../../modules/dnszones"

  subscription_id         = local.dnszones_input.subscription_id
  region                  = local.dnszones_input.region
  repo                    = local.dnszones_input.repo
  topology                = local.dnszones_input.topology
  tenant                  = local.dnszones_input.tenant
  environment             = local.dnszones_input.environment
  custom_zones            = local.dnszones_input.custom_zones
  disable_catalogue_zones = local.dnszones_input.disable_catalogue_zones
}
