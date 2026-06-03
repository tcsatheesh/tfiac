# Public contract — see specs/004-vnet/contracts/network-stack.md and
# specs/004-vnet/data-model.md for invariants.

variable "input" {
  description = "Engine input bundle. stack_purpose must be \"net\"."
  type = object({
    tenant        = string
    environment   = string
    region        = string
    usecase       = string
    stack_purpose = string
    repo          = string
  })

  validation {
    condition     = var.input.stack_purpose == "net"
    error_message = "input.stack_purpose must be \"net\" for the network wrapper module."
  }
}

variable "role" {
  description = "\"hub\" enables bastion + firewall; \"spoke\" enables peering. (VNET-INV-3)"
  type        = string

  validation {
    condition     = contains(["hub", "spoke"], var.role)
    error_message = "role must be \"hub\" or \"spoke\"."
  }
}

variable "address_space" {
  description = "Vnet address space. (VNET-INV-9)"
  type        = list(string)

  validation {
    condition     = length(var.address_space) >= 1
    error_message = "address_space must contain at least one CIDR."
  }

  validation {
    condition = alltrue([
      for c in var.address_space : can(cidrhost(c, 0))
    ])
    error_message = "every address_space entry must be a valid CIDR."
  }
}

variable "subnets" {
  description = "Map of subnet role => CIDR. Roles must exist in local.role_catalogue (VNET-INV-5)."
  type        = map(string)

  validation {
    condition = alltrue([
      for c in values(var.subnets) : can(cidrhost(c, 0))
    ])
    error_message = "every subnet CIDR must be valid."
  }

  validation {
    condition = alltrue([
      for r in keys(var.subnets) :
      contains([
        "development", "pre-production", "api-management", "buildsvr",
        "function-app", "logic-app", "preprod-func", "preprod-logic",
        "container-apps", "agents", "bastion", "firewall", "firewall-mgmt",
      ], r)
    ])
    error_message = "VNET-INV-5: every key in var.subnets must be one of: development, pre-production, api-management, buildsvr, function-app, logic-app, preprod-func, preprod-logic, container-apps, agents, bastion, firewall, firewall-mgmt."
  }

  # VNET-INV-10: hub deployments require bastion + firewall + firewall-mgmt
  # subnets. Cross-variable validation (Terraform >= 1.9).
  validation {
    condition = (
      var.role != "hub"
      || (
        contains(keys(var.subnets), "bastion")
        && contains(keys(var.subnets), "firewall")
        && contains(keys(var.subnets), "firewall-mgmt")
      )
    )
    error_message = "VNET-INV-10: hub role requires subnet roles \"bastion\", \"firewall\", and \"firewall-mgmt\" in var.subnets."
  }
}

variable "extra_nsg_rules" {
  description = "Optional caller-supplied per-role NSG rules (FR-207). Map keyed by subnet role; value is a list of azurerm-style rule objects passed straight through to the AVM NSG module's security_rules input."
  type        = map(any)
  default     = {}
}

variable "hub_vnet_id" {
  description = "Hub vnet resource_id (spoke only). Required when role == \"spoke\"."
  type        = string
  default     = null
}

variable "hub_firewall_private_ip" {
  description = "Hub firewall private IP (spoke only). Used as the next_hop for the spoke RT's 0.0.0.0/0 route."
  type        = string
  default     = null
}

variable "enable_hub_default_route" {
  description = "When role=hub, add 0.0.0.0/0 -> in-vnet firewall private IP to the shared hub route table (FR-210). Defaults to true so hub workload subnets (e.g. buildsvr) can reach the internet via the firewall."
  type        = bool
  default     = true
}

variable "enable_hub_firewall" {
  description = "When role=hub, deploy the in-vnet Azure Firewall (+ policy + the two PIPs) (FR-227). Defaults to true for day-one parity. When false the firewall is NOT created, the firewall-derived outputs resolve null, the hub default route is suppressed, and (per FR-228) no workload subnet attaches the shared route table. Ignored when role=spoke."
  type        = bool
  default     = true
}

variable "enable_hub_nat_gateway" {
  description = "When role=hub, deploy a Standard NAT gateway (+ its zone-redundant Standard static PIP) and associate it with the hub workload subnets that have needs_route_table=true (development, pre-production, buildsvr) (FR-229). Defaults to false (nothing created) for day-one parity. Provides a firewall-independent egress path so the hub firewall can be torn down with zero egress gap; the NAT association coexists with the firewall UDR (the UDR wins on routing precedence until removed). Ignored when role=spoke."
  type        = bool
  default     = false
}

variable "enable_spoke_nat_gateway" {
  description = "When role=spoke, deploy a Standard NAT gateway (+ its zone-redundant Standard static PIP) IN THE SPOKE'S OWN VNET/RG and associate it with the spoke workload subnets that have needs_route_table=true (development, pre-production, function-app, logic-app, preprod-func, preprod-logic) (FR-230). Defaults to false (nothing created) for day-one parity. A NAT gateway is not transitive over peering, so a spoke that needs internet egress must own one; while the hub firewall UDR is still present it wins on routing precedence and this NAT gateway sits dormant, taking over the moment that route is gone. Ignored when role=hub (the hub uses enable_hub_nat_gateway)."
  type        = bool
  default     = false
}

variable "hub_subscription_id" {
  description = "Hub subscription id (spoke only). Required for the peering submodule's hub-side provider."
  type        = string
  default     = null
}

variable "firewall_sku_tier" {
  description = "Azure Firewall + Firewall Policy SKU tier for hub deployments (FR-209). One of Basic, Standard, Premium. Ignored when role=spoke."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be one of \"Basic\", \"Standard\", or \"Premium\" (FR-209)."
  }
}
