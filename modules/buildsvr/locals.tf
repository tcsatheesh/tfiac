# Wrapper-module derivations.
#
# Engine emits the RG and VM canonical names. NIC / OS disk / data disk names
# are derived deterministically from the VM canonical name with stable prefixes
# (plan-time-known so snapshot tests are reliable and check.tf can enforce
# Azure max length).

locals {
  # Wrapper-level constants stamped into engine services list.
  vm_service_purpose = "bld"
  rg_key             = "main"
  vm_key             = "main"

  # Engine services list (RG + VM).
  engine_services = [
    {
      service_type    = "resource_group"
      key             = local.rg_key
      service_purpose = null
      stack_purpose   = null
      fqdn            = null
      extra_tags      = {}
    },
    {
      service_type    = "vm"
      key             = local.vm_key
      service_purpose = local.vm_service_purpose
      stack_purpose   = null
      fqdn            = null
      extra_tags      = {}
    },
  ]

  # Plan-time canonical names (mirroring the engine's hyphenated /
  # rg_hyphenated shapes; verified by check.tf precondition).
  vm_canonical_name = format(
    "vm-%s-%s-%s-%s-%s-001",
    local.vm_service_purpose,
    var.input.usecase,
    var.input.tenant,
    var.input.environment,
    var.input.region,
  )

  rg_canonical_name = format(
    "rg-%s-%s-%s-%s-%s-001",
    var.input.stack_purpose,
    var.input.usecase,
    var.input.tenant,
    var.input.environment,
    var.input.region,
  )

  # Derived names (not engine-emitted; deterministic, Azure-safe).
  nic_name       = format("nic-%s", local.vm_canonical_name)
  os_disk_name   = format("osdisk-%s", local.vm_canonical_name)
  data_disk_key  = "data0"
  data_disk_name = format("disk-%s-0", local.vm_canonical_name)

  diag_vm_name  = format("diag-%s-vm", local.vm_canonical_name)
  diag_nic_name = format("diag-%s-nic", local.vm_canonical_name)

  # Region long-form pulled off any engine tag.
  region_full = module.naming.names[local.rg_canonical_name].tags.region

  # Cloud-init rendered at plan time. Token redacted via sensitive var.
  cloud_init = templatefile("${path.module}/cloud-init.yaml.tpl", {
    admin_username        = var.admin_username
    github_runner_version = var.github_runner_version
    github_runner_url     = var.github_runner_url
    github_runner_token   = var.github_runner_token
    runner_labels         = join(",", var.runner_labels)
    runner_name           = local.vm_canonical_name
  })

  runner_status = var.github_runner_token == "" ? "unregistered" : "registered"
}
