###############################################################################
# terraform/log/backend.tf
#
# Partial backend config — populated at `terraform init` time via
# -backend-config. State key convention:  <env>/<scope>/log.tfstate
#
# For local testing only: `terraform init -backend=false`.
###############################################################################

terraform {
  backend "azurerm" {}
}
