locals {
  # ----- Naming engine input -----
  # stack_purpose "tfs" (terraform-state) -> rg-tfs-shd-hub-npd-swc-001.
  # SA service_purpose "tfs" + usecase "shd" -> sttfsshdhubnpdswc001 (21 chars).
  naming_input = {
    tenant        = var.tenant
    environment   = var.environment
    region        = var.region
    usecase       = "shd"
    stack_purpose = "tfs"
    repo          = var.repo
  }

  # ----- Engine services -----
  # The SA is a top-level entry; the RG is implicit via stack_purpose "tfs".
  engine_services = [
    {
      service_type    = "storage"
      service_purpose = "tfs"
      key             = "state"
      stack_purpose   = null
      fqdn            = null
      extra_tags      = {}
    },
    {
      service_type    = "resource_group"
      key             = "main"
      service_purpose = null
      stack_purpose   = null
      fqdn            = null
      extra_tags      = {}
    },
  ]

  # ----- Engine children -----
  # One PE on the SA (target subresource = "blob").
  engine_children = [
    {
      service_type  = "private_endpoint"
      parent_key    = "state"
      key           = "blob"
      child_purpose = null
      extra_tags    = {}
    },
  ]

  # ----- Locally-derived canonical names (plan-time known) -----
  sa_canonical_name = format(
    "st%s%s%s%s%s001",
    "tfs",
    "shd",
    var.tenant,
    var.environment,
    var.region,
  )

  rg_canonical_name = format(
    "rg-tfs-shd-%s-%s-%s-001",
    var.tenant, var.environment, var.region,
  )

  pe_canonical_name = format(
    "pep-st-tfs-shd-%s-%s-%s-001-001",
    var.tenant, var.environment, var.region,
  )

  # ----- Build VM (BOOT-INV-3: stable hub fixture; principal id comes from buildsvr remote_state) -----
  # ----- Resolved upstream values (override or remote_state) -----
  pe_subnet_id = (
    var.remote_state_override != null
    ? var.remote_state_override.pe_subnet_id
    : data.terraform_remote_state.vnet[0].outputs.subnets[var.pe_subnet_role].id
  )

  blob_zone_id = (
    var.remote_state_override != null
    ? var.remote_state_override.blob_zone_id
    : data.terraform_remote_state.dns[0].outputs.zone_ids["blob"]
  )

  blob_zone_name = (
    var.remote_state_override != null
    ? var.remote_state_override.blob_zone_name
    : data.terraform_remote_state.dns[0].outputs.zone_names["blob"]
  )

  dns_zone_rg = (
    var.remote_state_override != null
    ? var.remote_state_override.dns_zone_rg
    : data.terraform_remote_state.dns[0].outputs.resource_group_name
  )

  build_vm_principal_id = (
    var.build_vm_override != null
    ? var.build_vm_override.principal_id
    : data.terraform_remote_state.buildsvr[0].outputs.principal_id
  )

  region_full = module.naming.names[local.rg_canonical_name].tags.region
}
