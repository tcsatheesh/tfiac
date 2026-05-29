# engine: 0.1.0
#
# Naming Convention Engine
# ========================
# Pure-Terraform module that transforms a stack-level intent bundle
# (`var.input`, `var.services`, `var.children`, `var.extra_tags`)
# into a deterministic map keyed by canonical Azure resource name.
#
# Contract:  specs/001-naming-convention-engine/contracts/naming-engine.md
# Spec:      specs/001-naming-convention-engine/spec.md
# Data:      specs/001-naming-convention-engine/data-model.md
#
# Semver (engine_version):
#   MAJOR  - rename/remove an output field, remove a service_type,
#            change a name format, change a baseline tag key.
#   MINOR  - add a new service_type row, add a new region, add a new
#            optional input field with a non-null default.
#   PATCH  - error-message wording, internal locals refactor.
#
# Bump `output "engine_version"` and the header above in lock-step
# with any contract-affecting PR.

terraform {
  required_version = "~> 1.9"
}

# Catalogue is a child module so its files can live in the planned
# `catalogue/` subdirectory (Terraform does not auto-load .tf files
# from module sub-folders). Two outputs only: `services` and `regions`.
module "catalogue" {
  source = "./catalogue"
}
