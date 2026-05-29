# Backend keys (resource_group_name, storage_account_name, container_name, key)
# are supplied at `terraform init` time, e.g.:
#   terraform init \
#     -backend-config="resource_group_name=stcwe-rg-tfs-01" \
#     -backend-config="storage_account_name=stcwetfstate01" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=hub/npd/buildsvr.tfstate"
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
