# C-014 (Amendment 2026-05-31) — Shared hub Log Analytics workspace lookup.
# Reads `terraform/log/` outputs for the matching environment so every
# diagnostic-capable wrapper in this stack can wire its
# azurerm_monitor_diagnostic_setting at the SHARED hub workspace.
#
# Operationally: the `terraform/log/` stack for the target environment
# MUST be applied BEFORE this stack, or this data source fails with a
# clear "shared LA state lookup failed" message — see
# specs/006-services/quickstart.md § Troubleshooting.
data "terraform_remote_state" "hub_log" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group
    storage_account_name = var.tfstate_storage_account
    container_name       = var.tfstate_container
    key                  = "hub/${var.environment}/log.tfstate"
    use_azuread_auth     = true
    subscription_id      = var.subscription_id
  }
}

locals {
  # Stack-local shorthand consumed by every wrapper invocation in main.tf.
  # If a future operator needs to point a single stack at a non-default LA
  # (e.g. for an air-gapped POC), they should change the state key here AND
  # update the C-014 exemption rationale in the PR body.
  shared_la_workspace_id = data.terraform_remote_state.hub_log.outputs.workspace_resource_id
}
