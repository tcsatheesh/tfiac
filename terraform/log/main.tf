# T014 - root-stack composition.
# Single wrapper module call + plan-time subscription cross-check (FR-109, LOG-INV-5).

data "azurerm_client_config" "current" {}

check "subscription_match" {
  assert {
    condition     = var.subscription_id == data.azurerm_client_config.current.subscription_id
    error_message = "FR-109 / LOG-INV-5: var.subscription_id (${var.subscription_id}) does not match the active provider's subscription (${data.azurerm_client_config.current.subscription_id}). Run `az account set --subscription <id>` before plan/apply."
  }
}

module "loganalytics" {
  source = "../../modules/loganalytics"

  input             = local.naming_input
  retention_in_days = var.retention_in_days
  daily_quota_gb    = var.daily_quota_gb
  workspace_key     = var.workspace_key
}
