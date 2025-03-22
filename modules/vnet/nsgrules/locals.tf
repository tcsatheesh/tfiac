locals {
  nsg_rules = {
    api-management = local.api-management
    bastion        = local.bastion
  }
}