# TEMPORARY — sp01/dev Foundry drift recovery (2026-06-04).
#
# The first sp01/dev/services apply (run 26950234054) created the Cognitive
# Services Foundry account in Azure, but the Hosted-Agent network injection
# took longer than the 90m azapi create budget, so Terraform hit
# "context deadline exceeded" and exited BEFORE writing the account to state.
# A plain re-apply then failed with "Resource already exists — needs to be
# imported into the State". This config-based import adopts the existing
# account on the next pipeline apply so it can reconcile the BYO connections
# and capability host without any manual remote-state surgery.
#
# Scoped via for_each to the exact sp01/dev account name so it is an inert
# no-op for every other tenant/environment that shares this root module
# (their for_each is empty → no import target → no error). The extra guard on
# the all-zeros sentinel subscription keeps it inert under `terraform test`
# (every fixture uses 00000000-…-000000000000, and import is unsupported with
# mock providers). The injection path pins the account to api-version
# 2025-04-01-preview (see modules/aifoundry).
#
# REMOVE this file in a follow-up PR once the import has landed in state.
import {
  for_each = {
    for n, e in module.naming.names : n => e
    if e.service_type == "aifoundry"
    && n == "aif-uc1-uc1-sp01-dev-swc-001"
    && var.subscription_id != "00000000-0000-0000-0000-000000000000"
  }
  to = module.aifoundry[each.key].azapi_resource.this
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.svc.name}/providers/Microsoft.CognitiveServices/accounts/${each.key}?api-version=2025-04-01-preview"
}
