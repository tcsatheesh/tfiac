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
        "bastion", "firewall", "firewall-mgmt",
      ], r)
    ])
    error_message = "VNET-INV-5: every key in var.subnets must be one of: development, pre-production, api-management, buildsvr, function-app, logic-app, preprod-func, preprod-logic, bastion, firewall, firewall-mgmt."
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

variable "hub_subscription_id" {
  description = "Hub subscription id (spoke only). Required for the peering submodule's hub-side provider."
  type        = string
  default     = null
}
