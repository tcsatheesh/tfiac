# T003 - Azure Storage backend for the prd-hub DNS stack.
# Constitution Principle VII: state path = /<tenant>/<environment>/<purpose>.tfstate.
# Other backend fields (resource_group_name, storage_account_name, container_name,
# subscription_id) are supplied at init time via `-backend-config=variables/backend.hcl`.
terraform {
  backend "azurerm" {
    key = "hub/prd/dns.tfstate"
  }
}
