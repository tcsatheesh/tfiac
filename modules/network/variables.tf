###############################################################################
# modules/network/variables.tf
###############################################################################

variable "naming" {
  description = "Passthrough of module.naming.names from the root stack."
  type        = any
}

variable "by_type" {
  description = "Passthrough of module.naming.by_type."
  type        = any
}

variable "region" {
  description = "Azure region (e.g. swedencentral)."
  type        = string
}

variable "region_code" {
  description = "Engine region short code (e.g. sdc)."
  type        = string
}

variable "input" {
  description = "Engine input object — for tag derivation."
  type = object({
    topology    = string
    tenant      = string
    environment = string
    region      = string
    repo        = string
  })
}

variable "address_space" {
  description = "vnet address space (e.g. [\"10.240.4.0/23\"])."
  type        = list(string)
}

variable "subnets" {
  description = <<-EOT
  Map keyed by subnet **role** (from the module's subnet_role catalogue).
  Value is a single CIDR string. The module applies the role's
  catalogue defaults (NSG, route_table attachment, service_endpoints,
  delegation, Azure-mandated literal name).
  EOT
  type        = map(string)
}

variable "extra_nsg_rules" {
  description = <<-EOT
  Optional per-subnet-role extension rules. Map of role => list of
  azurerm_network_security_rule attribute objects (without
  network_security_group_name / resource_group_name).
  EOT
  type        = any
  default     = {}
}

variable "enable_bastion" {
  description = "Provision Azure Bastion (requires subnets.bastion). Hub-only."
  type        = bool
  default     = false
}

variable "enable_firewall" {
  description = "Provision Azure Firewall (requires subnets.firewall and subnets.firewall-mgmt). Hub-only."
  type        = bool
  default     = false
}

variable "default_route_next_hop_ip" {
  description = <<-EOT
  IP to which the per-vnet route table sends 0.0.0.0/0. For the hub
  stack this should be the firewall private IP (wired post-firewall
  via module.firewall.private_ip). For spoke stacks this is the hub
  firewall private IP read via terraform_remote_state. Empty string
  disables the default route.
  EOT
  type        = string
  default     = ""
}

variable "enable_default_route" {
  description = <<-EOT
  Toggle for creating the 0.0.0.0/0 -> firewall route. Must be known at
  plan time (do not derive from a resource attribute). When true,
  default_route_next_hop_ip is read at apply time.
  EOT
  type        = bool
  default     = false
}
