###############################################################################
# terraform/vnet/locals.tf
###############################################################################

locals {
  region_codes = { swedencentral = "sdc" }

  is_hub   = var.role == "hub"
  is_spoke = var.role == "spoke"

  # Subnet purposes feed the naming engine via services[].subnets.
  subnet_purposes = [for k in keys(var.subnets) : { purpose = k }]

  # Service catalogue as a uniform-typed map (so the for-comprehension below
  # produces a real list, not a tuple — required to avoid HCL ternary
  # tuple-length type errors). `include` is the role gate.
  service_specs = {
    vnet        = { type = "vnet", count = 1, subnets = local.subnet_purposes, include = true }
    route_table = { type = "route_table", count = 1, subnets = [], include = true }
    bastion     = { type = "bastion", count = 1, subnets = [], include = local.is_hub }
    firewall    = { type = "firewall", count = 1, subnets = [], include = local.is_hub }
    public_ip   = { type = "public_ip", count = 3, subnets = [], include = local.is_hub }
  }

  input = {
    topology    = var.topology
    tenant      = var.tenant
    environment = var.environment
    region      = var.region
    repo        = var.repo
    purpose     = "net"
    services    = [for k, s in local.service_specs : { type = s.type, count = s.count, subnets = s.subnets } if s.include]
  }
}
