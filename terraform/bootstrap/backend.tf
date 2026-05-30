# Feature 000-bootstrap - LOCAL backend by design (FR-009).
#
# This stack creates the hub-internal Terraform state SA. Its own state
# therefore cannot live there - the chicken-and-egg is resolved by keeping
# bootstrap state on the operator workstation only. The .gitignore in this
# directory excludes terraform.tfstate*. After the SA exists, every OTHER
# stack uses backend "azurerm" pointing at it via variables/backend.hcl.
terraform {
  backend "local" {}
}
