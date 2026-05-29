# Catalogue submodule: exposes the service & region maps as outputs.
# Loaded by the engine via `module "catalogue" { source = "./catalogue" }`
# so the catalogue files retain the planned `catalogue/` directory
# layout while still being consumed by the engine (root-level Terraform
# only auto-loads .tf files in the module root, hence the indirection).

terraform {
  required_version = "~> 1.9"
}

output "services" {
  value = local.services
}

output "regions" {
  value = local.regions
}
