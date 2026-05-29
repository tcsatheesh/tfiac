# T003 - Azure Storage backend for the centralised log-analytics stack.
# Per research D4: NO `key` field here. The key is supplied at init time via
#   terraform init -backend-config="key=hub/<env>/log.tfstate"
# so a single source tree supports both `hub/npd/log.tfstate` and
# `hub/prd/log.tfstate` without per-env code duplication (FR-113, Constitution VII).
# Other backend fields (resource_group_name, storage_account_name, container_name)
# are also supplied at init time, following the same pattern as the DNS stack.
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
