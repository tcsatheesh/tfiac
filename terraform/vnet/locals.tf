locals {
  naming_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = var.usecase
    stack_purpose = "net"
    repo          = var.repo
  }
}
