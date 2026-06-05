# Wrapper-module derivations.
#
# Engine emits the (existing) RG canonical name and the VM canonical name. NIC /
# OS disk / diagnostic names are derived deterministically from the VM canonical
# name with stable prefixes (plan-time-known so snapshot tests are reliable and
# check.tf can enforce Azure max length).

locals {
  # Wrapper-level constants stamped into engine services list.
  vm_service_purpose = "jmp"
  rg_key             = "main"
  vm_key             = "main"

  # Engine services list (RG reference + VM). The RG entry is present so the
  # naming engine emits its tags (used for tag derivation + the check.tf
  # precondition); the engine does NOT create the RG (FR-813).
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
  nic_name      = format("nic-%s", local.vm_canonical_name)
  os_disk_name  = format("osdisk-%s", local.vm_canonical_name)
  diag_vm_name  = format("diag-%s-vm", local.vm_canonical_name)
  diag_nic_name = format("diag-%s-nic", local.vm_canonical_name)

  # Windows computer (host) name: max 15 chars, alphanumeric only. The VM
  # resource name is too long for the hostname, so derive a short, stable one
  # from purpose + tenant + environment and truncate to the Windows limit.
  computer_name = substr(
    format("jmp%s%s", var.input.tenant, var.input.environment),
    0,
    15,
  )

  # Key Vault secret name for the generated admin password (FR-809).
  # vm_canonical_name already starts with "vm-" so this reads
  # vm-jmp-...-admin-password (matches spec "vm-<vmname>-admin-password").
  admin_password_secret_name = format("%s-admin-password", local.vm_canonical_name)

  # Region long-form pulled off any engine tag.
  region_full = module.naming.names[local.rg_canonical_name].tags.region
}
