###############################################################################
# terraform/vnet/backend.tf
#
# Partial backend config — populated at `terraform init` time via
# -backend-config. State key convention:  <env>/<scope>/vnet.tfstate
#   e.g. prd/hub/vnet.tfstate    or    prd/sp01/vnet.tfstate
#
# A spoke stack also reads the hub stack's state via the
# `data "terraform_remote_state" "hub"` block in main.tf — configure it through
# var.hub_state_backend ({storage_account_name, container_name,
# resource_group_name, key}).
#
# For local testing only: `terraform init -backend=false`.
###############################################################################

terraform {
  backend "azurerm" {}
}
