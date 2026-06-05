# Backend keys (resource_group_name, storage_account_name, container_name, key)
# are supplied at `terraform init` time, e.g.:
#   terraform init \
#     -backend-config="resource_group_name=rg-tfs-shd-hub-npd-swc-001" \
#     -backend-config="storage_account_name=sttfsshdhubnpdswc001" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=sp01/dev/winvm.tfstate"
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
