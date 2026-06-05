locals {
  naming_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = var.usecase
    stack_purpose = var.stack_purpose
    repo          = var.repo
  }

  subnet_resource_id = (
    var.vnet_state_override != null
    ? var.vnet_state_override.subnet_resource_id
    : data.terraform_remote_state.vnet[0].outputs.subnets[var.subnet_role].id
  )

  log_workspace_resource_id = (
    var.log_state_override != null
    ? var.log_state_override.workspace_resource_id
    : data.terraform_remote_state.log[0].outputs.workspace_resource_id
  )
}
