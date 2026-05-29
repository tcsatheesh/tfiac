locals {
  naming_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = var.usecase
    stack_purpose = "bld"
    repo          = var.repo
  }

  # Day-one default: grant Reader on the subscription so `az login --identity`
  # works out of the box. Merged into the caller-supplied map (caller wins
  # on key collisions).
  default_role_assignments = var.assign_subscription_reader ? {
    sub_reader = {
      scope_resource_id          = "/subscriptions/${var.subscription_id}"
      role_definition_id_or_name = "Reader"
      description                = "Build server MI: Reader on hub subscription (day-one default)"
    }
  } : {}

  identity_role_assignments = merge(local.default_role_assignments, var.identity_role_assignments)
}
