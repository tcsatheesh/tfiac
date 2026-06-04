# Foundry account + project system-assigned managed-identity principalIds, read
# at apply time from the live resources (the services stack creates them with
# identity { type = "SystemAssigned" }). count is gated on known-at-plan presence
# bools from the remote state; the principalId values themselves are computed and
# may be unknown at plan without breaking it (C-062).
data "azapi_resource" "account" {
  count                  = local.account_present ? 1 : 0
  type                   = "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
  resource_id            = local.account_id
  response_export_values = ["identity.principalId"]
}

data "azapi_resource" "project" {
  count                  = local.project_present ? 1 : 0
  type                   = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  resource_id            = local.project_id
  response_export_values = ["identity.principalId"]
}
