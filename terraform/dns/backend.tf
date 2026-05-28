###############################################################################
# terraform/dns/backend.tf
#
# Partial backend config — populated at `terraform init` time via
# -backend-config (or a .hcl backend file). State key convention:
#   <env>/<scope>/<service>.tfstate     e.g. prd/hub/dns.tfstate
#
# Example init:
#   terraform init -reconfigure \
#     -backend-config=../../variables/backend.hcl \
#     -backend-config="key=prd/hub/dns.tfstate"
#
# For local testing only (no Azure backend): `terraform init -backend=false`.
###############################################################################

terraform {
  backend "azurerm" {}
}
