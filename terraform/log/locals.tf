# T013 - root-stack derivations.
# Shapes the naming-engine input object from var.* and stamps the wrapper-level
# stack_purpose = "log" constant (research D5; LOG-INV).

locals {
  naming_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = "shd"
    stack_purpose = "log"
    repo          = var.repo
  }
}
