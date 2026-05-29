# Example consumer of the naming-convention engine.
# Exercises the inputs from specs/001-naming-convention-engine/quickstart.md §1.
# Run from this directory:
#   terraform init -backend=false
#   terraform plan
# The plan should report "1 to add, 0 to change, 0 to destroy" -
# the single resource is the engine's `terraform_data.assertions`
# stateless cross-field check; no Azure objects are created here.

module "names" {
  source = "../../../modules/naming"

  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }

  services = [
    { service_type = "resource_group", key = "main" },
    { service_type = "log_analytics", service_purpose = "lgs", key = "primary" },
    { service_type = "storage", service_purpose = "lgs", key = "audit" },
    { service_type = "keyvault", service_purpose = "app", key = "primary" },
    { service_type = "vnet", service_purpose = "net", key = "core" },
  ]

  children = [
    { service_type = "subnet", parent_key = "core", child_purpose = "app", key = "app" },
    { service_type = "subnet", parent_key = "core", child_purpose = "pep", key = "pep" },
    { service_type = "vnet_bastion", parent_key = "core", key = "bas" },
  ]

  extra_tags = {
    cost_center = "PLT-001"
    owner       = "platform-team"
  }
}
