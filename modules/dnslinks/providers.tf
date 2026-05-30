# Provider configuration contract for modules/dnslinks/.
#
# The submodule declares an OPTIONAL aliased azurerm provider
# (`azurerm.dns`) so the root stack can route link creation to the
# subscription that owns the parent private DNS zones (see plan §3).
#
# v1: vnet stack and DNS stack share subscription
# 883c9081-23ed-4674-95c5-45c74834e093 (npd-hub == prd-hub for shared
# services), so the root stack passes the default `azurerm` provider
# into both the unaliased and `azurerm.dns` slots. Forward-compat:
# when zones move to a separate subscription, the root stack swaps in
# a properly configured aliased provider with zero submodule change.
#
# Same pattern as modules/network/peering/ (azurerm.hub alias) — see
# README.md "Why bare resource (Constitution IX fallback)".

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.dns]
    }
  }
}
